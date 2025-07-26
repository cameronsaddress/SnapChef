import streamlit as st
from streamlit_extras.let_it_rain import rain
from utils.session import add_points
from components.topbar import render_topbar, add_floating_food_animation

def show_results():
    """Display recipe results with professional design"""
    
    # Render top bar
    render_topbar()
    
    # Add floating food animation
    add_floating_food_animation()
    
    # Professional styling
    st.markdown("""
        <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap');
        
        /* Gradient background */
        .stApp {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
        }
        
        /* Container */
        .main .block-container {
            padding-top: 70px !important; /* Account for fixed header */
            max-width: 900px !important;
            margin: 0 auto !important;
            padding-left: 1rem;
            padding-right: 1rem;
        }
        
        /* Typography */
        h1 {
            color: white !important;
            text-align: center !important;
            font-size: 2.5rem !important;
            font-weight: 800 !important;
            margin-bottom: 0.5rem !important;
            letter-spacing: -0.02em !important;
        }
        
        h3 {
            color: #1a1a1a !important;
            font-size: 1.5rem !important;
            font-weight: 700 !important;
            margin-bottom: 0.5rem !important;
        }
        
        .subtitle {
            color: rgba(255, 255, 255, 0.9);
            text-align: center;
            font-size: 1.1rem;
            margin-bottom: 2rem;
            font-weight: 400;
        }
        
        /* Ingredients section - gradient like recipes using :has() selector */
        div[data-testid="stVerticalBlock"]:has(.ingredients-container-marker) {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            border-radius: 24px;
            padding: 2rem;
            margin-bottom: 3rem;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.1);
            transition: all 0.3s ease;
            overflow: hidden;
        }
        
        div[data-testid="stVerticalBlock"]:has(.ingredients-container-marker):hover {
            transform: translateY(-4px);
            box-shadow: 0 15px 40px rgba(0, 0, 0, 0.15);
        }
        
        .ingredients-header {
            color: white;
            font-size: 1.25rem;
            font-weight: 700;
            margin-bottom: 1.25rem;
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }
        
        .ingredient-tag {
            display: inline-flex;
            align-items: center;
            background: #f8f9fa;
            color: #495057;
            padding: 0.4rem 1rem;
            border-radius: 20px;
            margin: 0.25rem;
            font-size: 0.875rem;
            font-weight: 500;
            border: 1px solid #e9ecef;
            transition: all 0.2s ease;
        }
        
        .ingredient-tag:hover {
            background: #e9ecef;
            transform: translateY(-1px);
        }
        
        /* Recipe cards - gradient background using :has() selector */
        div[data-testid="stVerticalBlock"]:has(.recipe-container-marker) {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            border-radius: 24px;
            padding: 2rem;
            margin-bottom: 2rem;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.1);
            transition: all 0.3s ease;
            overflow: hidden;
        }
        
        div[data-testid="stVerticalBlock"]:has(.recipe-container-marker):hover {
            transform: translateY(-4px);
            box-shadow: 0 15px 40px rgba(0, 0, 0, 0.15);
        }
        
        /* Ensure content stays within container */
        div[data-testid="stVerticalBlock"]:has(.recipe-container-marker) > div {
            overflow: visible;
        }
        
        .recipe-header {
            margin-bottom: 1rem;
        }
        
        .recipe-title {
            color: white !important;
            font-size: 1.875rem !important;
            font-weight: 700 !important;
            margin: 0 0 0.5rem 0 !important;
            line-height: 1.3 !important;
        }
        
        .recipe-content {
            /* Content is now directly in container */
        }
        
        .recipe-description {
            color: #1a1a1a;
            font-size: 1.0625rem;
            line-height: 1.6;
            margin-bottom: 1rem;
            background: rgba(255, 255, 255, 0.95);
            padding: 1rem;
            border-radius: 12px;
        }
        
        /* Metrics styling */
        [data-testid="metric-container"] {
            background: transparent;
            padding: 0.75rem;
            text-align: center;
            border: none !important;
        }
        
        [data-testid="metric-container"] label {
            color: #6c757d !important;
            font-size: 0.75rem !important;
            font-weight: 500 !important;
            text-transform: uppercase !important;
            letter-spacing: 0.05em !important;
        }
        
        [data-testid="metric-container"] [data-testid="metric-value"] {
            color: #1a1a1a !important;
            font-size: 1.25rem !important;
            font-weight: 600 !important;
        }
        
        /* Buttons - modern design */
        .stButton > button {
            background: white !important;
            color: #1a1a1a !important;
            border: 2px solid #e9ecef !important;
            padding: 0.75rem 1.75rem !important;
            font-weight: 600 !important;
            border-radius: 12px !important;
            transition: all 0.2s ease !important;
            font-size: 0.9375rem !important;
            box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05) !important;
        }
        
        .stButton > button:hover {
            background: #f8f9fa !important;
            border-color: #dee2e6 !important;
            transform: translateY(-2px) !important;
            box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1) !important;
        }
        
        /* Primary action button */
        .primary-action button {
            background: #1a1a1a !important;
            color: white !important;
            border: none !important;
        }
        
        .primary-action button:hover {
            background: #000 !important;
        }
        
        /* Logo hover effect */
        .logo-link:hover {
            opacity: 0.8;
            transform: translateY(-1px);
        }
        
        /* Recipe steps */
        .stExpander {
            background: #fafafa;
            border-radius: 8px;
            border: 1px solid #e9ecef !important;
            margin-top: 1rem;
        }
        
        .stExpander [data-testid="stExpanderToggleIcon"] {
            color: #6c757d !important;
        }
        
        /* Success messages */
        .stSuccess {
            background: #d4edda;
            border: 1px solid #c3e6cb;
            border-radius: 8px;
            color: #155724;
            font-weight: 500;
            font-size: 0.875rem;
        }
        
        /* Remove dividers */
        hr {
            display: none !important;
        }
        
        /* Global overflow fixes */
        .stApp {
            overflow-x: hidden;
        }
        
        /* Fix for expander overflow */
        div[data-testid="stExpander"] {
            width: 100%;
            overflow: hidden;
        }
        
        /* Ensure columns stay within container */
        div[data-testid="column"] {
            overflow: visible;
        }
        
        /* Fix button container overflow */
        .stButton {
            width: 100%;
        }
        
        /* Ensure all element containers respect parent boundaries */
        .element-container {
            width: 100%;
            max-width: 100%;
            overflow-x: auto;
        }
        
        /* Specific fix for recipe containers */
        div[data-testid="stVerticalBlock"]:has(.recipe-container-marker) .element-container {
            padding: 0;
            margin: 0;
        }
        
        /* Fallback for browsers without :has() support */
        @supports not selector(:has(*)) {
            /* Apply styles to all containers as fallback */
            .stContainer > div[data-testid="stVerticalBlock"] {
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                border-radius: 24px;
                padding: 2rem;
                margin-bottom: 2rem;
                box-shadow: 0 10px 30px rgba(0, 0, 0, 0.1);
                overflow: hidden;
            }
        }
        
        /* Additional containment fixes */
        div[data-testid="stVerticalBlock"] {
            position: relative;
            contain: layout style;
        }
        
        /* Bottom CTA */
        .bottom-section {
            text-align: center;
            margin: 3rem 0 2rem;
        }
        
        /* Free uses notice */
        .premium-notice {
            background: white;
            padding: 2rem;
            border-radius: 16px;
            text-align: center;
            margin-top: 2rem;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
            border: 1px solid #e9ecef;
        }
        
        .premium-notice h4 {
            color: #1a1a1a;
            font-size: 1.25rem;
            font-weight: 600;
            margin-bottom: 0.75rem;
        }
        
        .premium-notice p {
            color: #6c757d;
            font-size: 0.95rem;
            margin-bottom: 1.25rem;
        }
        
        /* Floating emojis */
        @keyframes float {
            0% { transform: translateY(0px) rotate(0deg); opacity: 0.03; }
            50% { transform: translateY(-20px) rotate(180deg); opacity: 0.05; }
            100% { transform: translateY(0px) rotate(360deg); opacity: 0.03; }
        }
        
        .floating-emoji {
            position: fixed;
            animation: float 6s ease-in-out infinite;
            pointer-events: none;
            z-index: 0;
        }
        /* Container overflow fixes */
        .stApp {
            overflow-x: hidden !important;
        }
        
        /* Target Streamlit containers with specific markers */
        div[data-testid="stVerticalBlock"]:has(.recipe-container-marker) {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            border-radius: 24px;
            padding: 2rem;
            margin-bottom: 2rem;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.1);
            transition: all 0.3s ease;
            overflow: hidden;
        }
        
        div[data-testid="stVerticalBlock"]:has(.recipe-container-marker):hover {
            transform: translateY(-4px);
            box-shadow: 0 15px 40px rgba(0, 0, 0, 0.15);
        }
        
        div[data-testid="stVerticalBlock"]:has(.ingredients-container-marker) {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            border-radius: 24px;
            padding: 2rem;
            margin-bottom: 3rem;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.1);
            transition: all 0.3s ease;
        }
        
        /* Ensure all elements stay within containers */
        .element-container {
            width: 100% !important;
            max-width: 100% !important;
        }
        
        /* Recipe elements inside containers */
        .recipe-container-marker + * {
            width: 100%;
        }
        
        </style>
    """, unsafe_allow_html=True)
    
    # Floating food is handled by add_floating_food_animation()
    
    # Celebration
    rain(emoji="✨", font_size=20, falling_speed=5, animation_length=1)
    
    # No need for logo here, it's in the top bar now
    
    # Title
    st.markdown("# Your Personalized Recipes ✨")
    st.markdown('<p class="subtitle">Crafted from the ingredients in your fridge</p>', unsafe_allow_html=True)
    
    # Ingredients section
    ingredients = st.session_state.get('detected_ingredients', [])
    if ingredients:
        with st.container():
            # Apply unique identifier for CSS targeting
            st.markdown('<div class="ingredients-container-marker"></div>', unsafe_allow_html=True)
            st.markdown('<div class="ingredients-header">🔍 We found these ingredients in your fridge</div>', unsafe_allow_html=True)
            
            # Create ingredient tags
            ingredients_html = '<div style="display: flex; flex-wrap: wrap; gap: 0.5rem;">'
            for ing in ingredients:
                # Handle both dict and string formats
                if isinstance(ing, dict):
                    name = ing.get('name', '')
                    quantity = ing.get('quantity', '')
                    unit = ing.get('unit', '')
                    # Format the ingredient display
                    if quantity and unit:
                        display_text = f"{name} ({quantity} {unit})"
                    elif quantity:
                        display_text = f"{name} ({quantity})"
                    else:
                        display_text = name
                else:
                    display_text = str(ing)
                
                ingredients_html += f'<span class="ingredient-tag">✓ {display_text}</span>'
            ingredients_html += '</div>'
            
            st.markdown(ingredients_html, unsafe_allow_html=True)
    
    # Recipes
    recipes = st.session_state.get('generated_recipes', [])
    
    if recipes:
        for idx, recipe in enumerate(recipes):
            # Use st.container() to properly contain all elements
            with st.container():
                # Apply unique identifier for CSS targeting
                container_id = f"recipe-container-{idx}"
                st.markdown(f'<div id="{container_id}" class="recipe-container-marker"></div>', unsafe_allow_html=True)
                
                # Recipe header
                st.markdown(f'<h3 class="recipe-title">{recipe.get("name", "Untitled Recipe")}</h3>', unsafe_allow_html=True)
                st.markdown(f'<p class="recipe-description">{recipe.get("description", "")}</p>', unsafe_allow_html=True)
                
                # Main and Side dish tags
                main_dish = recipe.get('main_dish', '')
                side_dish = recipe.get('side_dish', '')
                if main_dish or side_dish:
                    tags_html = '<div style="display: flex; gap: 0.75rem; margin-top: 1rem; flex-wrap: wrap;">'
                    if main_dish:
                        tags_html += f'<span style="background: #e3f2fd; color: #1976d2; padding: 0.375rem 0.875rem; border-radius: 20px; font-size: 0.875rem; font-weight: 500; border: 1px solid #bbdefb;">🍽️ Main: {main_dish}</span>'
                    if side_dish:
                        tags_html += f'<span style="background: #f3e5f5; color: #7b1fa2; padding: 0.375rem 0.875rem; border-radius: 20px; font-size: 0.875rem; font-weight: 500; border: 1px solid #e1bee7;">🥗 Side: {side_dish}</span>'
                    tags_html += '</div>'
                    st.markdown(tags_html, unsafe_allow_html=True)
                
                # Metrics in single white card
                total_time = recipe.get('total_time', recipe.get('prep_time', 15) + recipe.get('cook_time', 15))
                calories = recipe.get('nutrition', {}).get('calories', 'N/A')
                servings = recipe.get('servings', 4)
                difficulty = recipe.get('difficulty', 'easy').title()
                difficulty_color = '#28a745' if difficulty.lower() == 'easy' else '#ffc107' if difficulty.lower() == 'medium' else '#dc3545'
                
                st.markdown(f'''
                    <div style="background: white; padding: 5px; border-radius: 12px; margin: 1.5rem 0;">
                        <div style="display: flex; justify-content: space-around; align-items: center; flex-wrap: wrap;">
                            <div style="text-align: center; padding: 0.5rem 1rem;">
                                <span style="font-size: 1.2rem;">⏱️</span>
                                <span style="font-size: 1.1rem; font-weight: 600; color: #1a1a1a; margin-left: 0.5rem;">{total_time} min</span>
                            </div>
                            <div style="text-align: center; padding: 0.5rem 1rem;">
                                <span style="font-size: 1.2rem;">🔥</span>
                                <span style="font-size: 1.1rem; font-weight: 600; color: #1a1a1a; margin-left: 0.5rem;">{calories} cal</span>
                            </div>
                            <div style="text-align: center; padding: 0.5rem 1rem;">
                                <span style="font-size: 1.2rem;">👥</span>
                                <span style="font-size: 1.1rem; font-weight: 600; color: #1a1a1a; margin-left: 0.5rem;">{servings} servings</span>
                            </div>
                            <div style="text-align: center; padding: 0.5rem 1rem;">
                                <span style="font-size: 1.2rem;">📊</span>
                                <span style="font-size: 1.1rem; font-weight: 600; color: {difficulty_color}; margin-left: 0.5rem;">{difficulty}</span>
                            </div>
                        </div>
                    </div>
                ''', unsafe_allow_html=True)
                
                # Spacing before action buttons
                st.markdown("<div style='height: 1.5rem;'></div>", unsafe_allow_html=True)
                
                # Action buttons - only Instructions and Share
                btn_col1, btn_col2 = st.columns(2)
                
                with btn_col1:
                    steps_key = f"show_steps_{idx}"
                    is_expanded = st.session_state.get(steps_key, False)
                    
                    if st.button(
                        "📋 Hide Instructions" if is_expanded else "📋 Instructions", 
                        key=f"steps_{idx}", 
                        use_container_width=True
                    ):
                        st.session_state[steps_key] = not is_expanded
                        st.rerun()
                
                with btn_col2:
                    if st.button("📱 Share Your SnapChef Recipe!", key=f"share_{idx}", use_container_width=True):
                        with st.expander("Share this recipe", expanded=True):
                            share_text = f"I just made {recipe.get('name', 'this amazing dish')} using SnapChef! 🍳✨"
                            st.code(share_text)
                            share_col1, share_col2 = st.columns(2)
                            with share_col1:
                                st.button("Share to TikTok", key=f"tiktok_{idx}", use_container_width=True)
                            with share_col2:
                                st.button("Share to Instagram", key=f"ig_{idx}", use_container_width=True)
                
                # Recipe steps
                if st.session_state.get(f"show_steps_{idx}", False):
                    with st.expander("Step-by-Step Instructions", expanded=True):
                        # Try different keys for instructions
                        steps = recipe.get('instructions', recipe.get('recipe', []))
                        if steps:
                            for i, step in enumerate(steps, 1):
                                st.markdown(f"**Step {i}:** {step}")
                                # No dividers between steps
                        else:
                            st.info("Detailed steps will be available soon.")
            
            # Add spacing between recipes
            if idx < len(recipes) - 1:
                st.markdown("<div style='height: 2rem;'></div>", unsafe_allow_html=True)
    
    else:
        st.error("No recipes were generated. Please try again with a clearer photo.")
    
    # Bottom CTA
    st.markdown('<div class="bottom-section">', unsafe_allow_html=True)
    col1, col2, col3 = st.columns([1, 2, 1])
    with col2:
        st.markdown('<div class="primary-action">', unsafe_allow_html=True)
        if st.button("Snap Another Fridge", key="new_snap", use_container_width=True, icon="📸"):
            # Reset states
            st.session_state.photo_taken = False
            st.session_state.processing = False
            st.session_state.photo = None
            st.session_state.detected_ingredients = []
            st.session_state.generated_recipes = []
            st.session_state.current_page = 'camera'
            st.rerun()
        st.markdown('</div>', unsafe_allow_html=True)
    st.markdown('</div>', unsafe_allow_html=True)
    
    # Premium notice for free users
    if st.session_state.get('free_uses', 3) <= 0:
        st.markdown("""
        <div class="premium-notice">
            <h4>🎉 You're on a roll!</h4>
            <p>You've used all your free snaps. Upgrade to continue creating amazing recipes.</p>
        </div>
        """, unsafe_allow_html=True)
        
        col1, col2, col3 = st.columns([1, 2, 1])
        with col2:
            if st.button("✨ Upgrade to Premium", key="upgrade_btn", use_container_width=True):
                st.session_state.current_page = 'auth'
                st.rerun()
    
    # Debug section (only show if responses exist)
    if st.session_state.get('raw_combined_response') or st.session_state.get('raw_ingredient_response') or st.session_state.get('raw_recipe_response'):
        st.markdown("<br><br><hr>", unsafe_allow_html=True)
        
        # Small debug toggle at bottom
        if st.button("🔧 Show Debug Info", key="debug_toggle", help="View raw LLM responses for troubleshooting"):
            st.session_state.show_debug = not st.session_state.get('show_debug', False)
        
        if st.session_state.get('show_debug', False):
            st.markdown("### 🔍 Debug Information")
            
            # Show raw combined response (new single API call)
            if st.session_state.get('raw_combined_response'):
                with st.expander("🍳 Raw Vision Model Response (Single API Call)", expanded=True):
                    st.code(st.session_state.raw_combined_response, language="json")
            
            # Show raw ingredient detection response (old separate call)
            elif st.session_state.get('raw_ingredient_response'):
                with st.expander("📦 Raw Ingredient Detection Response", expanded=False):
                    st.code(st.session_state.raw_ingredient_response, language="json")
            
            # Show raw recipe generation response (old separate call)
            if st.session_state.get('raw_recipe_response'):
                with st.expander("🍳 Raw Recipe Generation Response", expanded=False):
                    st.code(st.session_state.raw_recipe_response, language="json")
            
            # Show detected ingredients
            if ingredients:
                with st.expander("🧾 Detected Ingredients", expanded=False):
                    st.json(ingredients)
            
            # Clear debug info button
            if st.button("🗑️ Clear Debug Info", key="clear_debug"):
                if 'raw_combined_response' in st.session_state:
                    del st.session_state.raw_combined_response
                if 'raw_ingredient_response' in st.session_state:
                    del st.session_state.raw_ingredient_response
                if 'raw_recipe_response' in st.session_state:
                    del st.session_state.raw_recipe_response
                st.session_state.show_debug = False
                st.rerun()