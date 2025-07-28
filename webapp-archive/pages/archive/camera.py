import streamlit as st
from streamlit_extras.let_it_rain import rain
import time
from utils.api import encode_image_to_base64, detect_ingredients, generate_meals
from utils.session import update_streak, add_points
from utils.logo import render_logo

def show_camera():
    # Modern camera UI styling
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
        </style>
    """, unsafe_allow_html=True)
    
    # Initialize states
    if 'photo_processed' not in st.session_state:
        st.session_state.photo_processed = False
    if 'recipes_generated' not in st.session_state:
        st.session_state.recipes_generated = False
    
    # Header with back button
    col1, col2, col3 = st.columns([1, 2, 1])
    
    with col1:
        if st.button("←", key="back_btn"):
            st.session_state.current_page = 'landing'
            st.rerun()
    
    with col2:
        st.markdown(render_logo("small", gradient=False), unsafe_allow_html=True)
    
    # Camera section
    if not st.session_state.photo_processed:
        st.markdown('<p class="status-text">📸 Snap your fridge</p>', unsafe_allow_html=True)
        
        # Tabs for camera/upload
        tab1, tab2 = st.tabs(["Camera", "Upload"])
        
        with tab1:
            photo = st.camera_input("", label_visibility="collapsed", key="camera_widget")
            
            if photo:
                st.session_state.photo = photo
                st.session_state.photo_processed = True
                st.rerun()
        
        with tab2:
            uploaded = st.file_uploader(
                "Drop your photo here",
                type=['jpg', 'jpeg', 'png'],
                key="file_uploader"
            )
            
            if uploaded:
                st.session_state.photo = uploaded
                st.session_state.photo_processed = True
                st.rerun()
    
    elif not st.session_state.recipes_generated:
        # Process the photo
        process_and_generate_recipes()
    
    else:
        # Show generated recipes
        display_recipes()

def process_and_generate_recipes():
    """Process photo and generate recipes with modern UI"""
    
    # Display the photo
    col1, col2, col3 = st.columns([1, 2, 1])
    with col2:
        st.image(st.session_state.photo, use_column_width=True)
    
    # Progress indicator
    progress_placeholder = st.empty()
    status_placeholder = st.empty()
    
    # Animated processing
    status_placeholder.markdown('<p class="status-text">✨ Analyzing ingredients...</p>', unsafe_allow_html=True)
    
    progress_html = """
    <div class="progress-container">
        <div class="progress-bar" style="width: {}%"></div>
    </div>
    """
    
    # Simulate progress
    for i in range(0, 40, 5):
        progress_placeholder.markdown(progress_html.format(i), unsafe_allow_html=True)
        time.sleep(0.1)
    
    # Convert and detect
    photo_bytes = st.session_state.photo.getvalue() if hasattr(st.session_state.photo, 'getvalue') else st.session_state.photo.read()
    photo_base64 = encode_image_to_base64(photo_bytes)
    
    ingredients = detect_ingredients(photo_base64)
    
    # Show ingredients
    status_placeholder.markdown('<p class="status-text">🎯 Found your ingredients!</p>', unsafe_allow_html=True)
    
    for i in range(40, 70, 5):
        progress_placeholder.markdown(progress_html.format(i), unsafe_allow_html=True)
        time.sleep(0.05)
    
    # Display ingredients
    ingredient_html = '<div class="ingredient-list">'
    for ing in ingredients:
        ingredient_html += f'<span class="ingredient-pill">{ing}</span>'
    ingredient_html += '</div>'
    
    st.markdown(ingredient_html, unsafe_allow_html=True)
    
    # Generate recipes
    status_placeholder.markdown('<p class="status-text">👨‍🍳 Creating personalized recipes...</p>', unsafe_allow_html=True)
    
    for i in range(70, 100, 5):
        progress_placeholder.markdown(progress_html.format(i), unsafe_allow_html=True)
        time.sleep(0.05)
    
    # Get recipes
    recipes = generate_meals(ingredients, [])
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
    update_streak()
    add_points(10, "Generated recipes")
    
    st.session_state.recipes_generated = True
    st.rerun()

def display_recipes():
    """Display recipes with modern cards"""
    
    st.markdown('<h2 style="text-align: center; color: white; margin: 40px 0;">Your Personalized Recipes ✨</h2>', unsafe_allow_html=True)
    
    # Recipe cards
    for idx, recipe in enumerate(st.session_state.recipes):
        recipe_html = f"""
        <div class="recipe-card">
            <div class="recipe-header">
                <div>
                    <h3 class="recipe-title">{recipe['name']}</h3>
                    <p class="recipe-description">{recipe['description']}</p>
                </div>
            </div>
            
            <div class="recipe-stats">
                <div class="stat-item">
                    <span>⏱️</span>
                    <span>{recipe.get('prep_time', 15) + recipe.get('cook_time', 15)} min</span>
                </div>
                <div class="stat-item">
                    <span>🔥</span>
                    <span>{recipe.get('nutrition', {}).get('calories', 'N/A')} cal</span>
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
                add_points(20, "Cooked recipe")
        
        with col2:
            if st.button("📱 Share", key=f"share_{idx}", use_container_width=True):
                with st.expander("Share Recipe", expanded=True):
                    st.code(recipe.get('share_caption', 'Check out my SnapChef recipe!'))
                    col_a, col_b = st.columns(2)
                    with col_a:
                        st.button("TikTok", key=f"tiktok_{idx}", use_container_width=True)
                    with col_b:
                        st.button("Instagram", key=f"ig_{idx}", use_container_width=True)
        
        with col3:
            if st.button("📋 Details", key=f"details_{idx}", use_container_width=True):
                with st.expander("Recipe Steps", expanded=True):
                    for i, step in enumerate(recipe.get('recipe', []), 1):
                        st.write(f"{i}. {step}")
    
    # Bottom actions
    st.markdown("<br><br>", unsafe_allow_html=True)
    
    col1, col2, col3 = st.columns([1, 2, 1])
    with col2:
        if st.button("📸 Snap Another Fridge", key="snap_another", use_container_width=True, type="primary"):
            # Reset states
            st.session_state.photo_processed = False
            st.session_state.recipes_generated = False
            st.session_state.photo = None
            st.rerun()
        
        if st.session_state.free_uses <= 0:
            st.info("🎉 You've used all your free snaps! Sign up to continue.")
            if st.button("Sign Up Free", key="signup_prompt", use_container_width=True):
                st.session_state.current_page = 'auth'
                st.rerun()