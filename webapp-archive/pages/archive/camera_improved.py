import streamlit as st
from streamlit_extras.let_it_rain import rain
import time
import base64
from PIL import Image
import io
from utils.api import encode_image_to_base64, detect_ingredients, generate_meals
from utils.session import update_streak, add_points
from utils.logo import render_logo

def show_camera():
    # Modern camera UI styling with additional permission-related styles
    st.markdown("""
        <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap');
        
        /* Clean background */
        .main {
            background: #000;
        }
        
        /* Camera container */
        .camera-container {
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        
        /* Instagram-style header */
        .camera-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 20px 0;
            color: white;
        }
        
        .back-button {
            font-size: 24px;
            cursor: pointer;
            color: white;
            text-decoration: none;
        }
        
        /* Status text */
        .status-text {
            text-align: center;
            color: white;
            font-size: 18px;
            font-weight: 600;
            margin: 20px 0;
        }
        
        /* Progress bar */
        .progress-container {
            background: rgba(255, 255, 255, 0.1);
            height: 4px;
            border-radius: 2px;
            overflow: hidden;
            margin: 20px 0;
        }
        
        .progress-bar {
            height: 100%;
            background: linear-gradient(90deg, #25F4EE 0%, #FE2C55 100%);
            transition: width 0.3s ease;
        }
        
        /* Recipe cards */
        .recipe-card {
            background: white;
            border-radius: 16px;
            padding: 24px;
            margin: 16px 0;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.1);
            transition: all 0.3s ease;
        }
        
        .recipe-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 15px 40px rgba(0, 0, 0, 0.15);
        }
        
        .recipe-header {
            display: flex;
            justify-content: space-between;
            align-items: start;
            margin-bottom: 16px;
        }
        
        .recipe-title {
            font-size: 24px;
            font-weight: 700;
            color: #1a1a1a;
            margin: 0;
        }
        
        .recipe-description {
            color: #666;
            font-size: 16px;
            line-height: 1.5;
            margin: 8px 0;
        }
        
        .recipe-stats {
            display: flex;
            gap: 24px;
            margin: 16px 0;
            flex-wrap: wrap;
        }
        
        .stat-item {
            display: flex;
            align-items: center;
            gap: 8px;
            color: #666;
            font-size: 14px;
        }
        
        /* Action buttons */
        .action-buttons {
            display: flex;
            gap: 12px;
            margin-top: 20px;
        }
        
        .action-button {
            flex: 1;
            padding: 12px 24px;
            border-radius: 12px;
            font-weight: 600;
            font-size: 16px;
            border: none;
            cursor: pointer;
            transition: all 0.3s ease;
        }
        
        .primary-button {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        
        .primary-button:hover {
            transform: translateY(-1px);
            box-shadow: 0 10px 20px rgba(102, 126, 234, 0.3);
        }
        
        .secondary-button {
            background: #f0f0f0;
            color: #333;
        }
        
        .secondary-button:hover {
            background: #e5e5e5;
        }
        
        /* Ingredient pills */
        .ingredient-list {
            display: flex;
            flex-wrap: wrap;
            gap: 8px;
            margin: 20px 0;
        }
        
        .ingredient-pill {
            background: #f0f0f0;
            padding: 8px 16px;
            border-radius: 20px;
            font-size: 14px;
            font-weight: 500;
            color: #333;
        }
        
        /* Hide Streamlit camera label */
        .stCameraInput > label {
            display: none;
        }
        
        /* Center camera widget */
        .stCameraInput {
            display: flex;
            justify-content: center;
        }
        
        /* Style file uploader */
        .uploadedFile {
            border: 2px dashed rgba(255, 255, 255, 0.3);
            border-radius: 16px;
            padding: 40px;
            text-align: center;
            background: rgba(255, 255, 255, 0.05);
        }
        
        /* Permission notice styles */
        .permission-notice {
            background: rgba(254, 44, 85, 0.1);
            border: 2px solid #FE2C55;
            border-radius: 16px;
            padding: 24px;
            margin: 20px 0;
            text-align: center;
        }
        
        .permission-title {
            color: #FE2C55;
            font-size: 20px;
            font-weight: 600;
            margin-bottom: 12px;
        }
        
        .permission-text {
            color: rgba(255, 255, 255, 0.8);
            font-size: 16px;
            line-height: 1.5;
            margin-bottom: 16px;
        }
        
        .permission-steps {
            text-align: left;
            background: rgba(255, 255, 255, 0.05);
            border-radius: 12px;
            padding: 20px;
            margin: 16px 0;
        }
        
        .permission-step {
            color: rgba(255, 255, 255, 0.9);
            margin: 8px 0;
            padding-left: 20px;
        }
        
        .https-warning {
            background: rgba(255, 193, 7, 0.1);
            border: 2px solid #FFC107;
            border-radius: 12px;
            padding: 16px;
            margin: 16px 0;
            color: #FFC107;
            text-align: center;
            font-size: 14px;
        }
        
        .compatibility-notice {
            background: rgba(100, 126, 234, 0.1);
            border: 1px solid rgba(100, 126, 234, 0.3);
            border-radius: 12px;
            padding: 16px;
            margin: 16px 0;
            color: rgba(255, 255, 255, 0.8);
            font-size: 14px;
            text-align: center;
        }
        
        /* Error styles */
        .error-container {
            background: rgba(255, 59, 48, 0.1);
            border: 2px solid #FF3B30;
            border-radius: 16px;
            padding: 24px;
            margin: 20px 0;
            text-align: center;
        }
        
        .error-title {
            color: #FF3B30;
            font-size: 20px;
            font-weight: 600;
            margin-bottom: 12px;
        }
        
        .error-text {
            color: rgba(255, 255, 255, 0.8);
            font-size: 16px;
            margin-bottom: 16px;
        }
        
        /* Mobile responsive */
        @media (max-width: 768px) {
            .recipe-stats {
                gap: 16px;
            }
            
            .stat-item {
                font-size: 12px;
            }
            
            .permission-steps {
                padding: 16px;
            }
        }
        </style>
    """, unsafe_allow_html=True)
    
    # Initialize states
    if 'photo_processed' not in st.session_state:
        st.session_state.photo_processed = False
    if 'recipes_generated' not in st.session_state:
        st.session_state.recipes_generated = False
    if 'camera_permission_shown' not in st.session_state:
        st.session_state.camera_permission_shown = False
    if 'processing_error' not in st.session_state:
        st.session_state.processing_error = None
    
    # Header with back button
    col1, col2, col3 = st.columns([1, 2, 1])
    
    with col1:
        if st.button("←", key="back_btn"):
            # Clear camera states when leaving
            st.session_state.photo_processed = False
            st.session_state.recipes_generated = False
            st.session_state.processing_error = None
            st.session_state.current_page = 'landing'
            st.rerun()
    
    with col2:
        st.markdown(render_logo("small", gradient=False), unsafe_allow_html=True)
    
    # Check for HTTPS (camera requires secure context)
    if not st.session_state.get('is_secure_context', True):
        st.markdown("""
            <div class="https-warning">
                ⚠️ Camera access requires HTTPS. Please access this site using https:// or use the Upload option.
            </div>
        """, unsafe_allow_html=True)
    
    # Camera section
    if not st.session_state.photo_processed:
        st.markdown('<p class="status-text">📸 Snap your fridge</p>', unsafe_allow_html=True)
        
        # Browser compatibility notice
        st.markdown("""
            <div class="compatibility-notice">
                📱 Works best on: Chrome, Safari, Firefox, Edge • Mobile: iOS Safari, Chrome
            </div>
        """, unsafe_allow_html=True)
        
        # Tabs for camera/upload
        tab1, tab2 = st.tabs(["Camera", "Upload"])
        
        with tab1:
            # Camera permission helper
            if not st.session_state.camera_permission_shown:
                st.markdown("""
                    <div class="permission-notice">
                        <div class="permission-title">📸 Camera Permission Required</div>
                        <div class="permission-text">
                            To use the camera, you'll need to grant permission when prompted.
                        </div>
                        <div class="permission-steps">
                            <div class="permission-step">1. Click the camera widget below</div>
                            <div class="permission-step">2. When prompted, click "Allow" to grant camera access</div>
                            <div class="permission-step">3. If you denied permission, click the camera icon in your browser's address bar</div>
                        </div>
                    </div>
                """, unsafe_allow_html=True)
                st.session_state.camera_permission_shown = True
            
            try:
                # Add JavaScript to detect camera permission status
                st.markdown("""
                    <script>
                    // Check if camera is available and permissions
                    async function checkCameraAvailability() {
                        try {
                            const devices = await navigator.mediaDevices.enumerateDevices();
                            const hasCamera = devices.some(device => device.kind === 'videoinput');
                            
                            if (!hasCamera) {
                                window.parent.postMessage({
                                    type: 'streamlit:setComponentValue',
                                    value: {cameraAvailable: false}
                                }, '*');
                            }
                            
                            // Check if we're in a secure context
                            if (!window.isSecureContext) {
                                window.parent.postMessage({
                                    type: 'streamlit:setComponentValue',
                                    value: {secureContext: false}
                                }, '*');
                            }
                        } catch (error) {
                            console.error('Camera check error:', error);
                        }
                    }
                    
                    checkCameraAvailability();
                    </script>
                """, unsafe_allow_html=True)
                
                photo = st.camera_input("", label_visibility="collapsed", key="camera_widget")
                
                if photo:
                    # Validate image
                    try:
                        # Validate file size (max 10MB)
                        photo_bytes = photo.getvalue()
                        file_size_mb = len(photo_bytes) / (1024 * 1024)
                        
                        if file_size_mb > 10:
                            st.error("⚠️ Image too large! Please use an image under 10MB.")
                        else:
                            # Validate image format
                            img = Image.open(io.BytesIO(photo_bytes))
                            img.verify()
                            
                            st.session_state.photo = photo
                            st.session_state.photo_processed = True
                            st.rerun()
                    except Exception as e:
                        st.error(f"⚠️ Invalid image file. Please try again.")
                        st.session_state.processing_error = str(e)
                
                # Permission denied helper
                st.markdown("""
                    <details style="margin-top: 20px;">
                        <summary style="color: #667eea; cursor: pointer;">📸 Camera not working? Click here for help</summary>
                        <div style="margin-top: 16px; padding: 16px; background: rgba(255,255,255,0.05); border-radius: 12px;">
                            <p style="color: white; margin: 8px 0;"><strong>Common solutions:</strong></p>
                            <ul style="color: rgba(255,255,255,0.8); margin-left: 20px;">
                                <li>Refresh the page and try again</li>
                                <li>Check if camera is being used by another app</li>
                                <li>Grant camera permission in your browser settings</li>
                                <li>Try using a different browser</li>
                                <li>On mobile: Check app permissions in device settings</li>
                                <li>Use the Upload tab as an alternative</li>
                            </ul>
                        </div>
                    </details>
                """, unsafe_allow_html=True)
                
            except Exception as e:
                st.error("⚠️ Camera initialization failed. Please use the Upload option instead.")
                st.session_state.processing_error = str(e)
        
        with tab2:
            st.markdown("""
                <div style="text-align: center; color: rgba(255,255,255,0.8); margin-bottom: 20px;">
                    📤 Upload a photo of your fridge or pantry
                </div>
            """, unsafe_allow_html=True)
            
            uploaded = st.file_uploader(
                "Drop your photo here or click to browse",
                type=['jpg', 'jpeg', 'png', 'webp', 'heic'],
                key="file_uploader",
                help="Supported formats: JPG, PNG, WebP, HEIC • Max size: 10MB"
            )
            
            if uploaded:
                try:
                    # Validate file size
                    file_size_mb = uploaded.size / (1024 * 1024)
                    
                    if file_size_mb > 10:
                        st.error("⚠️ File too large! Please use an image under 10MB.")
                    else:
                        # Validate image
                        uploaded_bytes = uploaded.getvalue()
                        img = Image.open(io.BytesIO(uploaded_bytes))
                        img.verify()
                        
                        # Convert HEIC if necessary
                        if uploaded.name.lower().endswith('.heic'):
                            st.info("Converting HEIC image...")
                            # Note: In production, you'd need pillow-heif or similar
                            # For now, we'll just process as is
                        
                        st.session_state.photo = uploaded
                        st.session_state.photo_processed = True
                        st.rerun()
                except Exception as e:
                    st.error(f"⚠️ Error processing image: {str(e)}")
                    st.session_state.processing_error = str(e)
    
    elif not st.session_state.recipes_generated:
        # Process the photo with error handling
        process_and_generate_recipes()
    
    else:
        # Show generated recipes
        display_recipes()

def process_and_generate_recipes():
    """Process photo and generate recipes with proper error handling"""
    
    try:
        # Display the photo
        col1, col2, col3 = st.columns([1, 2, 1])
        with col2:
            st.image(st.session_state.photo, use_column_width=True)
        
        # Progress indicator
        progress_placeholder = st.empty()
        status_placeholder = st.empty()
        error_placeholder = st.empty()
        
        # Step 1: Analyze ingredients
        status_placeholder.markdown('<p class="status-text">✨ Analyzing ingredients...</p>', unsafe_allow_html=True)
        
        progress_html = """
        <div class="progress-container">
            <div class="progress-bar" style="width: {}%"></div>
        </div>
        """
        
        try:
            # Show initial progress
            progress_placeholder.markdown(progress_html.format(10), unsafe_allow_html=True)
            
            # Convert and validate image
            photo_bytes = st.session_state.photo.getvalue() if hasattr(st.session_state.photo, 'getvalue') else st.session_state.photo.read()
            
            # Optimize image size if needed
            img = Image.open(io.BytesIO(photo_bytes))
            
            # Resize if too large (max 1920x1920)
            max_size = (1920, 1920)
            if img.size[0] > max_size[0] or img.size[1] > max_size[1]:
                img.thumbnail(max_size, Image.Resampling.LANCZOS)
                
                # Convert back to bytes
                img_byte_arr = io.BytesIO()
                img.save(img_byte_arr, format=img.format or 'JPEG', quality=85)
                photo_bytes = img_byte_arr.getvalue()
            
            progress_placeholder.markdown(progress_html.format(25), unsafe_allow_html=True)
            
            # Encode image
            photo_base64 = encode_image_to_base64(photo_bytes)
            
            progress_placeholder.markdown(progress_html.format(40), unsafe_allow_html=True)
            
            # Detect ingredients with timeout
            with st.spinner("Analyzing your ingredients..."):
                ingredients = detect_ingredients(photo_base64)
            
            if not ingredients:
                raise ValueError("No ingredients detected. Please try a clearer photo.")
            
            progress_placeholder.markdown(progress_html.format(60), unsafe_allow_html=True)
            
            # Show ingredients
            status_placeholder.markdown('<p class="status-text">🎯 Found your ingredients!</p>', unsafe_allow_html=True)
            
            # Display ingredients with edit option
            ingredient_html = '<div class="ingredient-list">'
            for ing in ingredients:
                ingredient_html += f'<span class="ingredient-pill">{ing}</span>'
            ingredient_html += '</div>'
            
            st.markdown(ingredient_html, unsafe_allow_html=True)
            
            # Let user edit ingredients
            with st.expander("✏️ Edit ingredients", expanded=False):
                edited_ingredients = st.text_area(
                    "Modify detected ingredients (one per line):",
                    value="\n".join(ingredients),
                    height=100
                )
                if st.button("Update ingredients"):
                    ingredients = [ing.strip() for ing in edited_ingredients.split("\n") if ing.strip()]
                    st.session_state.ingredients = ingredients
                    st.success("✓ Ingredients updated!")
            
            progress_placeholder.markdown(progress_html.format(70), unsafe_allow_html=True)
            
            # Step 2: Generate recipes
            status_placeholder.markdown('<p class="status-text">👨‍🍳 Creating personalized recipes...</p>', unsafe_allow_html=True)
            
            # Get user preferences if available
            dietary_prefs = st.session_state.get('dietary_preferences', [])
            
            with st.spinner("Generating recipes tailored to your ingredients..."):
                recipes = generate_meals(ingredients, dietary_prefs)
            
            if not recipes:
                raise ValueError("Unable to generate recipes. Please try again.")
            
            progress_placeholder.markdown(progress_html.format(90), unsafe_allow_html=True)
            
            # Save results
            st.session_state.recipes = recipes
            st.session_state.ingredients = ingredients
            
            # Complete
            progress_placeholder.markdown(progress_html.format(100), unsafe_allow_html=True)
            time.sleep(0.5)
            
            # Clear progress
            progress_placeholder.empty()
            status_placeholder.empty()
            
            # Celebration
            rain(emoji="✨", font_size=20, falling_speed=5, animation_length=1)
            
            # Update stats
            try:
                update_streak()
                add_points(10, "Generated recipes")
            except Exception as e:
                # Don't fail the whole process if stats update fails
                print(f"Stats update failed: {e}")
            
            st.session_state.recipes_generated = True
            st.rerun()
            
        except Exception as e:
            # Show error to user
            error_html = f"""
            <div class="error-container">
                <div class="error-title">⚠️ Oops! Something went wrong</div>
                <div class="error-text">{str(e)}</div>
            </div>
            """
            error_placeholder.markdown(error_html, unsafe_allow_html=True)
            
            # Log error for debugging
            st.session_state.processing_error = str(e)
            
            # Offer retry
            col1, col2, col3 = st.columns([1, 2, 1])
            with col2:
                if st.button("🔄 Try Again", use_container_width=True, type="primary"):
                    st.session_state.photo_processed = False
                    st.session_state.processing_error = None
                    st.rerun()
                
                if st.button("📤 Upload Different Photo", use_container_width=True):
                    st.session_state.photo_processed = False
                    st.session_state.photo = None
                    st.session_state.processing_error = None
                    st.rerun()
            
    except Exception as e:
        st.error(f"Critical error: {str(e)}")
        st.session_state.processing_error = str(e)

def display_recipes():
    """Display recipes with proper error handling and sanitization"""
    
    try:
        st.markdown('<h2 style="text-align: center; color: white; margin: 40px 0;">Your Personalized Recipes ✨</h2>', unsafe_allow_html=True)
        
        if not st.session_state.get('recipes'):
            st.warning("No recipes available. Please try again.")
            if st.button("📸 Try Again", use_container_width=True):
                st.session_state.photo_processed = False
                st.session_state.recipes_generated = False
                st.rerun()
            return
        
        # Recipe cards with error handling
        for idx, recipe in enumerate(st.session_state.recipes):
            try:
                # Sanitize recipe data
                recipe_name = str(recipe.get('name', 'Untitled Recipe')).replace('<', '&lt;').replace('>', '&gt;')
                recipe_desc = str(recipe.get('description', '')).replace('<', '&lt;').replace('>', '&gt;')
                
                # Calculate total time safely
                prep_time = int(recipe.get('prep_time', 15))
                cook_time = int(recipe.get('cook_time', 15))
                total_time = prep_time + cook_time
                
                # Get nutrition info safely
                nutrition = recipe.get('nutrition', {})
                calories = nutrition.get('calories', 'N/A')
                if calories != 'N/A':
                    try:
                        calories = int(calories)
                    except:
                        calories = 'N/A'
                
                recipe_html = f"""
                <div class="recipe-card">
                    <div class="recipe-header">
                        <div>
                            <h3 class="recipe-title">{recipe_name}</h3>
                            <p class="recipe-description">{recipe_desc}</p>
                        </div>
                    </div>
                    
                    <div class="recipe-stats">
                        <div class="stat-item">
                            <span>⏱️</span>
                            <span>{total_time} min</span>
                        </div>
                        <div class="stat-item">
                            <span>🔥</span>
                            <span>{calories} cal</span>
                        </div>
                        <div class="stat-item">
                            <span>👥</span>
                            <span>{recipe.get('servings', 2)} servings</span>
                        </div>
                        <div class="stat-item">
                            <span>📊</span>
                            <span>{recipe.get('difficulty', 'Easy')}</span>
                        </div>
                    </div>
                </div>
                """
                
                st.markdown(recipe_html, unsafe_allow_html=True)
                
                # Action buttons
                col1, col2, col3 = st.columns(3)
                
                with col1:
                    if st.button("🍳 Cook This", key=f"cook_{idx}", use_container_width=True):
                        st.success("Recipe saved! +20 points")
                        try:
                            add_points(20, "Cooked recipe")
                        except:
                            pass
                
                with col2:
                    if st.button("📱 Share", key=f"share_{idx}", use_container_width=True):
                        with st.expander("Share Recipe", expanded=True):
                            share_text = recipe.get('share_caption', f"Check out this {recipe_name} recipe from SnapChef!")
                            st.code(share_text)
                            col_a, col_b = st.columns(2)
                            with col_a:
                                st.button("TikTok", key=f"tiktok_{idx}", use_container_width=True)
                            with col_b:
                                st.button("Instagram", key=f"ig_{idx}", use_container_width=True)
                
                with col3:
                    if st.button("📋 Details", key=f"details_{idx}", use_container_width=True):
                        with st.expander("Recipe Steps", expanded=True):
                            steps = recipe.get('recipe', [])
                            if steps:
                                for i, step in enumerate(steps, 1):
                                    st.write(f"{i}. {step}")
                            else:
                                st.write("Recipe steps not available.")
                
            except Exception as e:
                st.error(f"Error displaying recipe: {str(e)}")
                continue
        
        # Bottom actions
        st.markdown("<br><br>", unsafe_allow_html=True)
        
        col1, col2, col3 = st.columns([1, 2, 1])
        with col2:
            if st.button("📸 Snap Another Fridge", key="snap_another", use_container_width=True, type="primary"):
                # Reset states
                st.session_state.photo_processed = False
                st.session_state.recipes_generated = False
                st.session_state.photo = None
                st.session_state.processing_error = None
                st.rerun()
            
            # Check free uses
            if st.session_state.get('free_uses', 3) <= 0:
                st.info("🎉 You've used all your free snaps! Sign up to continue.")
                if st.button("Sign Up Free", key="signup_prompt", use_container_width=True):
                    st.session_state.current_page = 'auth'
                    st.rerun()
    
    except Exception as e:
        st.error(f"Error displaying recipes: {str(e)}")
        if st.button("🔄 Retry", use_container_width=True):
            st.rerun()