import streamlit as st
from streamlit_extras.let_it_rain import rain
import time
from PIL import Image
import io
from utils.api import encode_image_to_base64, analyze_fridge_and_generate_recipes
from utils.session import update_streak, add_points
from prompts import get_random_progress_message
from prompts.loading_messages import LOADING_MESSAGES
import random
from components.topbar import render_topbar, add_floating_food_animation

def show_camera():
    # Apply gradient background and minimal styling FIRST
    st.markdown("""
        <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap');
        
        /* Gradient background */
        .stApp {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            overflow-x: hidden;
        }
        
        /* Force topbar to absolute top */
        .top-bar {
            position: fixed !important;
            top: 0 !important;
            left: 0 !important;
            right: 0 !important;
            width: 100vw !important;
            z-index: 99999 !important;
        }
        
        /* Remove any parent transforms */
        .main {
            transform: none !important;
            position: static !important;
        }
        
        /* Ensure stApp is the outermost container */
        body > div:first-child {
            position: static !important;
        }
        
        /* Match structure of landing/results pages */
        .main > div {
            padding-top: 2rem;
        }
        
        /* Remove top padding and use full width for camera page */
        .main .block-container {
            padding-top: 65px !important; /* 60px header + 5px spacing */
            max-width: 100% !important;
            padding-left: 1rem !important;
            padding-right: 1rem !important;
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
        
        /* Camera container - full viewport approach */
        div[data-testid="stCameraInput"] {
            position: relative !important;
            height: calc(100vh - 120px) !important;
            height: calc(100dvh - 120px) !important; /* Dynamic viewport height for mobile */
            max-height: calc(100vh - 120px) !important;
            width: calc(100vw - 2rem) !important;
            margin: 0 auto;
            display: flex !important;
            flex-direction: column !important;
            align-items: center !important;
            justify-content: center !important;
        }
        
        /* Target all levels of camera component */
        div[data-testid="stCameraInput"] > div {
            height: 100% !important;
            width: 100% !important;
            max-width: 100% !important;
            display: flex !important;
            flex-direction: column !important;
            align-items: center !important;
            justify-content: center !important;
            background: transparent !important;
        }
        
        /* Remove white background from all camera elements */
        div[data-testid="stCameraInput"],
        div[data-testid="stCameraInput"] > div,
        div[data-testid="stCameraInput"] > div > div {
            background: transparent !important;
            background-color: transparent !important;
        }
        
        /* The actual video/image elements */
        div[data-testid="stCameraInput"] video,
        div[data-testid="stCameraInput"] img {
            height: 100% !important;
            width: auto !important;
            max-width: 100% !important;
            max-height: 100% !important;
            object-fit: contain !important;
            border-radius: 20px !important;
            overflow: hidden !important;
        }
        
        /* Alternative selectors for broader compatibility */
        .stCameraInput {
            height: calc(100vh - 150px) !important;
            height: -webkit-fill-available !important;
        }
        
        .stCameraInput > div > div {
            height: 100% !important;
        }
        
        /* Mobile responsive adjustments */
        @media (max-width: 768px) {
            div[data-testid="stCameraInput"] {
                height: calc(100vh - 100px) !important;
                height: calc(100dvh - 100px) !important;
                height: -webkit-fill-available !important;
                width: calc(100vw - 1rem) !important;
            }
            
            div[data-testid="stCameraInput"] video,
            div[data-testid="stCameraInput"] img {
                border-radius: 16px !important;
            }
            
            .main .block-container {
                padding-top: 65px !important; /* 60px header + 5px spacing */
                padding-left: 0.5rem !important;
                padding-right: 0.5rem !important;
                max-width: 100% !important;
            }
        }
        
        /* Hide default camera label */
        .stCameraInput > label {
            display: none !important;
        }
        
        /* Style the camera button container - move to top */
        .stCameraInput > div {
            display: flex !important;
            flex-direction: column-reverse !important;
        }
        
        .stCameraInput > div > div:last-child {
            width: 100%;
            display: flex;
            justify-content: center;
            margin-bottom: 1rem;
            margin-top: 0;
            order: -1; /* Move to top */
        }
        
        /* Style the Take Photo button with teal color */
        .stCameraInput button {
            background: #25F4EE !important;
            color: #1a1a1a !important;
            border: none !important;
            padding: 0.75rem 2rem !important;
            font-size: 1rem !important;
            font-weight: 600 !important;
            border-radius: 25px !important;
            box-shadow: 0 4px 15px rgba(37, 244, 238, 0.3) !important;
            transition: all 0.2s ease !important;
        }
        
        .stCameraInput button:hover {
            background: #00E5DB !important;
            transform: translateY(-2px) !important;
            box-shadow: 0 6px 20px rgba(37, 244, 238, 0.4) !important;
        }
        
        /* Target camera video container for proper button positioning */
        div[data-testid="stCameraInput"] > div > div:has(video) {
            position: relative !important;
        }
        
        /* Camera swap button - use more specific targeting */
        div[data-testid="stCameraInput"] button[kind="secondary"],
        div[data-testid="stCameraInput"] button:has(svg),
        div[data-testid="stCameraInput"] > div > div > button,
        button[aria-label*="Switch camera"] {
            position: absolute !important;
            top: 10px !important;
            left: 50% !important;
            transform: translateX(-50%) !important;
            right: auto !important;
            z-index: 1000 !important;
            background: rgba(255, 255, 255, 0.9) !important;
            border-radius: 50% !important;
            width: 40px !important;
            height: 40px !important;
            min-width: 40px !important;
            min-height: 40px !important;
            padding: 0 !important;
            display: flex !important;
            align-items: center !important;
            justify-content: center !important;
            margin: 0 !important;
            box-shadow: 0 2px 5px rgba(0,0,0,0.2) !important;
        }
        
        /* Hide text button that appears after flip */
        div[data-testid="stCameraInput"] button:not(:has(svg)),
        div[data-testid="stCameraInput"] button[kind="secondary"]:not(:has(svg)),
        button:contains("Switch camera") {
            display: none !important;
        }
        
        /* Ensure only icon button is visible */
        div[data-testid="stCameraInput"] button svg {
            width: 20px !important;
            height: 20px !important;
        }
        
        
        /* Page header */
        .camera-header {
            font-size: clamp(0.9rem, 4vw, 2.5rem);
            font-weight: 800;
            text-align: center;
            margin-top: 0;
            margin-bottom: 1rem;
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
            letter-spacing: -0.02em;
            color: white !important;
            text-decoration: none !important;
            position: relative;
            z-index: 20;
            white-space: normal;
            line-height: 1.2;
            padding: 0 1rem;
            display: block;
            width: 100%;
        }
        
        @media (max-width: 420px) {
            .camera-header {
                font-size: clamp(0.8rem, 3.5vw, 1.5rem);
            }
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
        
        /* Override Streamlit error and info message colors */
        .stAlert {
            background: rgba(255, 255, 255, 0.1) !important;
            backdrop-filter: blur(10px) !important;
            border: 1px solid rgba(255, 255, 255, 0.2) !important;
        }
        
        .stAlert > div {
            color: white !important;
        }
        
        .stAlert svg {
            fill: white !important;
        }
        
        </style>
    """, unsafe_allow_html=True)
    
    # Initialize states BEFORE rendering anything
    if 'photo_taken' not in st.session_state:
        st.session_state.photo_taken = False
    if 'processing' not in st.session_state:
        st.session_state.processing = False
    if 'processing_complete' not in st.session_state:
        st.session_state.processing_complete = False
    
    # Render top bar AFTER CSS
    render_topbar()
    
    # Add floating food animation AFTER CSS
    add_floating_food_animation()
    
    # Add styled header
    st.markdown('<h1 class="camera-header">Take a photo of your fridge or pantry</h1>', unsafe_allow_html=True)
    
    # Check if we need to show an error
    if st.session_state.get('show_error', False):
        error_msg = st.session_state.get('error_message', 'An error occurred')
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
            if st.button("📸 Take Another Photo", use_container_width=True, key="retry_photo_main"):
                # Clear error state
                st.session_state.show_error = False
                st.session_state.error_message = None
                if 'photo' in st.session_state:
                    del st.session_state.photo
                st.rerun()
        
        # Don't show camera if error is displayed
        return
    
    # Process photo if taken and not yet processed
    if st.session_state.photo_taken and st.session_state.processing:
        process_photo_with_progress()
    else:
        # Camera input without label - with back camera preference
        photo = st.camera_input("Camera", 
                               label_visibility="collapsed",
                               key="camera_input",
                               help="Take a photo of your fridge or pantry")
        
        # Add JavaScript to try to use back camera and resize camera to full viewport
        st.markdown("""
        <script>
        // Function to resize camera to full viewport
        function resizeCameraToFullViewport() {
            const cameraContainers = document.querySelectorAll('[data-testid="stCameraInput"]');
            const viewportHeight = window.innerHeight;
            const viewportWidth = window.innerWidth;
            const headerHeight = 120; // Adjust based on your header
            const targetHeight = viewportHeight - headerHeight;
            const targetWidth = viewportWidth - 32; // Account for padding
            
            cameraContainers.forEach(container => {
                // Set container height and width
                container.style.height = targetHeight + 'px';
                container.style.maxHeight = targetHeight + 'px';
                container.style.width = targetWidth + 'px';
                container.style.maxWidth = targetWidth + 'px';
                container.style.setProperty('height', targetHeight + 'px', 'important');
                container.style.setProperty('width', targetWidth + 'px', 'important');
                
                // Find and resize video/img elements
                const videos = container.querySelectorAll('video');
                const images = container.querySelectorAll('img');
                
                videos.forEach(video => {
                    video.style.height = '100%';
                    video.style.width = 'auto';
                    video.style.maxHeight = '100%';
                    video.style.maxWidth = '100%';
                    video.style.setProperty('height', '100%', 'important');
                    video.style.objectFit = 'contain';
                });
                
                images.forEach(img => {
                    img.style.height = '100%';
                    img.style.width = 'auto';
                    img.style.maxHeight = '100%';
                    img.style.maxWidth = '100%';
                    img.style.setProperty('height', '100%', 'important');
                    img.style.objectFit = 'contain';
                });
                
                // Also resize parent divs
                const childDivs = container.querySelectorAll('div');
                childDivs.forEach(div => {
                    div.style.height = '100%';
                    div.style.maxHeight = '100%';
                    div.style.width = '100%';
                    div.style.maxWidth = '100%';
                });
            });
        }
        
        // Function to switch to back camera
        function switchToBackCamera() {
            const videoElements = document.querySelectorAll('video');
            videoElements.forEach(video => {
                if (video && video.srcObject) {
                    const tracks = video.srcObject.getTracks();
                    tracks.forEach(track => {
                        if (track.kind === 'video') {
                            // Stop the current track
                            track.stop();
                            
                            // Request new stream with back camera
                            navigator.mediaDevices.getUserMedia({
                                video: { 
                                    facingMode: { exact: 'environment' },
                                    width: { ideal: 1920 },
                                    height: { ideal: 1080 }
                                }
                            }).then(newStream => {
                                video.srcObject = newStream;
                            }).catch(err => {
                                // Fallback to any camera if rear not available
                                navigator.mediaDevices.getUserMedia({
                                    video: { 
                                        facingMode: 'environment',
                                        width: { ideal: 1920 },
                                        height: { ideal: 1080 }
                                    }
                                }).then(newStream => {
                                    video.srcObject = newStream;
                                }).catch(e => console.log('Camera error:', e));
                            });
                        }
                    });
                }
            });
        }
        
        // Try to use back camera on mobile devices
        document.addEventListener('DOMContentLoaded', function() {
            // Resize camera on load
            resizeCameraToFullViewport();
            
            // Try to switch to back camera after a delay
            setTimeout(switchToBackCamera, 500);
        });
        
        // Resize on window resize
        window.addEventListener('resize', resizeCameraToFullViewport);
        
        // Use MutationObserver to catch when camera loads
        const observer = new MutationObserver(function(mutations) {
            const hasCameraInput = document.querySelector('[data-testid="stCameraInput"]');
            if (hasCameraInput) {
                resizeCameraToFullViewport();
                
                // Also try to switch to back camera when video element appears
                const video = hasCameraInput.querySelector('video');
                if (video && !video.hasAttribute('data-camera-switched')) {
                    video.setAttribute('data-camera-switched', 'true');
                    setTimeout(switchToBackCamera, 100);
                }
            }
        });
        
        // Start observing
        observer.observe(document.body, {
            childList: true,
            subtree: true
        });
        
        // Also try resizing after a delay
        setTimeout(resizeCameraToFullViewport, 500);
        setTimeout(resizeCameraToFullViewport, 1000);
        
        // Function to fix camera button positioning and hide text buttons
        function fixCameraButtons() {
            // Find all buttons in camera input
            const cameraInput = document.querySelector('[data-testid="stCameraInput"]');
            if (!cameraInput) return;
            
            const buttons = cameraInput.querySelectorAll('button');
            buttons.forEach(button => {
                // Check if button contains text (not icon)
                const hasText = button.textContent && button.textContent.trim().length > 0 && !button.querySelector('svg');
                if (hasText && (button.textContent.includes('Switch') || button.textContent.includes('switch'))) {
                    // Hide text buttons
                    button.style.display = 'none';
                }
                
                // Position icon buttons in center
                if (button.querySelector('svg')) {
                    button.style.position = 'absolute';
                    button.style.top = '10px';
                    button.style.left = '50%';
                    button.style.transform = 'translateX(-50%)';
                    button.style.right = 'auto';
                    button.style.zIndex = '1000';
                }
            });
        }
        
        // Run button fix on load and mutations
        document.addEventListener('DOMContentLoaded', function() {
            fixCameraButtons();
            
            // Watch for changes
            const observer = new MutationObserver(function(mutations) {
                fixCameraButtons();
            });
            
            const cameraContainer = document.querySelector('[data-testid="stCameraInput"]');
            if (cameraContainer) {
                observer.observe(cameraContainer, {
                    childList: true,
                    subtree: true,
                    attributes: true
                });
            }
        });
        
        // Also run periodically to catch dynamic changes
        setInterval(fixCameraButtons, 500);
        </script>
        """, unsafe_allow_html=True)
        
        if photo and not st.session_state.photo_taken:
            st.session_state.photo = photo
            st.session_state.photo_taken = True
            st.session_state.processing = True
            st.rerun()

def process_photo_with_progress():
    """Process photo with progress bar - rebuilt for reliability"""
    
    # Create containers for different UI sections
    progress_container = st.container()
    image_container = st.container()
    
    with progress_container:
        # Style for progress container
        st.markdown("""
            <style>
            /* Style progress bar */
            .stProgress {
                max-width: 400px;
                margin: 0 auto;
            }
            
            /* Style for progress section */
            .progress-section {
                background: rgba(0, 0, 0, 0.2);
                backdrop-filter: blur(10px);
                padding: 1.5rem;
                border-radius: 20px;
                text-align: center;
                margin: 0 auto 2rem auto;
                max-width: 500px;
                min-height: 100px;
            }
            
            .status-text {
                color: white;
                font-size: 1.2rem;
                margin-top: 1rem;
            }
            
            @media (max-width: 768px) {
                .progress-section {
                    padding: 1rem;
                    margin: 0 auto 1rem auto;
                }
            }
            </style>
        """, unsafe_allow_html=True)
        
        # Progress bar and status
        progress_bar = st.progress(0)
        status_placeholder = st.empty()
    
    with image_container:
        # Show the camera preview with the captured image
        if hasattr(st.session_state, 'photo') and st.session_state.photo:
            # Add styling for the captured image
            st.markdown("""
                <style>
                /* Container to match camera size - responsive */
                .image-container {
                    width: 100%;
                    margin: 2rem auto 0;
                    height: calc(100vh - 300px);
                    height: calc(100dvh - 300px);
                    display: flex;
                    align-items: center;
                    justify-content: center;
                }
                
                /* Round the captured image */
                .image-container .stImage > img {
                    border-radius: 20px !important;
                    height: 100%;
                    width: auto;
                    max-width: 100%;
                    max-height: 100%;
                    object-fit: contain;
                }
                
                /* Mobile adjustments for captured image */
                @media (max-width: 768px) {
                    .image-container {
                        height: calc(100vh - 250px);
                        height: calc(100dvh - 250px);
                    }
                    
                    .image-container .stImage > img {
                        border-radius: 16px !important;
                    }
                }
                </style>
            """, unsafe_allow_html=True)
            
            st.image(st.session_state.photo, use_container_width=True)
    
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
        with status_placeholder.container():
            st.markdown(f'<p class="status-text">{messages[0][0]}</p>', unsafe_allow_html=True)
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
        with status_placeholder.container():
            st.markdown(f'<p class="status-text">{messages[1][0]}</p>', unsafe_allow_html=True)
        progress_bar.progress(messages[1][1])
        time.sleep(0.8)
        
        # Encode image
        photo_base64 = encode_image_to_base64(photo_bytes)
        
        # Show detecting message
        with status_placeholder.container():
            st.markdown(f'<p class="status-text">{messages[2][0]}</p>', unsafe_allow_html=True)
        progress_bar.progress(messages[2][1])
        time.sleep(0.5)
        
        # Make single API call for ingredients and recipes with rotating messages
        import threading
        import queue
        
        # Create a queue to store the API result
        result_queue = queue.Queue()
        
        # Function to run API call in background
        def api_call_thread():
            api_result = analyze_fridge_and_generate_recipes(
                photo_base64, 
                st.session_state.get('dietary_preferences', [])
            )
            result_queue.put(api_result)
        
        # Start API call in background thread
        api_thread = threading.Thread(target=api_call_thread)
        api_thread.start()
        
        # Show rotating messages while waiting
        message_index = 0
        progress_value = 20
        
        while api_thread.is_alive():
            # Update message
            current_message = LOADING_MESSAGES[message_index % len(LOADING_MESSAGES)]
            with status_placeholder.container():
                st.markdown(f'<p class="status-text">{current_message}</p>', unsafe_allow_html=True)
            
            # Update progress bar (slowly increase from 20 to 80)
            if progress_value < 80:
                progress_value += 2
            progress_bar.progress(progress_value)
            
            # Move to next message
            message_index += 1
            time.sleep(1.5)  # Show each message for 1.5 seconds
        
        # Get the result from the queue
        result = result_queue.get()
        
        print(f"API Result: {result}")  # Debug logging
        
        # Check if analysis was successful
        if 'error' in result or (len(result.get('ingredients', [])) == 0 and len(result.get('recipes', [])) == 0):
            error_msg = result.get('error', 'No ingredients found in the image.')
            print(f"Showing error: {error_msg}")  # Debug logging
            
            # Reset processing state FIRST
            st.session_state.processing = False
            st.session_state.photo_taken = False
            
            # Force a complete page refresh to show error
            st.session_state.show_error = True
            st.session_state.error_message = error_msg
            st.rerun()
        
        # Extract data from result
        ingredients = result.get('ingredients', [])
        recipes = result.get('recipes', [])
        
        # Show remaining progress messages
        for i in range(3, len(messages)):
            with status_placeholder.container():
                st.markdown(f'<p class="status-text">{messages[i][0]}</p>', unsafe_allow_html=True)
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
        
        # Mark processing as complete and navigate to results
        st.session_state.processing = False
        st.session_state.current_page = 'results'
        
        # Small delay before navigation
        time.sleep(1)
        st.rerun()
        
    except Exception as e:
        print(f"Exception occurred: {str(e)}")  # Debug logging
        
        # Determine error message
        error_message = str(e)
        if "API" in error_message or "api_key" in error_message:
            display_error = "API Error: Please check your API key configuration."
        elif "connection" in error_message.lower() or "network" in error_message.lower():
            display_error = "Network Error: Please check your internet connection."
        else:
            display_error = f"Oops! Something went wrong: {error_message}"
        
        # Reset processing state and show error
        st.session_state.processing = False
        st.session_state.photo_taken = False
        st.session_state.show_error = True
        st.session_state.error_message = display_error
        st.rerun()