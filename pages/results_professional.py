import streamlit as st
from streamlit_extras.let_it_rain import rain
from utils.session import add_points

def show_results():
    """Display recipe results with professional design"""
    
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
            padding-top: 1rem !important;
            max-width: 900px !important;
            margin: 0 auto !important;
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
        
        /* Ingredients section */
        .ingredients-container {
            background: white;
            border-radius: 16px;
            padding: 1.5rem;
            margin-bottom: 2rem;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
            border: 1px solid #e9ecef;
        }
        
        .ingredients-header {
            color: #1a1a1a;
            font-size: 1rem;
            font-weight: 600;
            margin-bottom: 1rem;
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
        
        /* Recipe cards */
        .recipe-container {
            background: white;
            border-radius: 16px;
            overflow: hidden;
            margin-bottom: 1.5rem;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
            border: 1px solid #e9ecef;
            transition: all 0.2s ease;
        }
        
        .recipe-container:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 16px rgba(0, 0, 0, 0.12);
        }
        
        .recipe-header {
            padding: 1.5rem;
            border-bottom: 1px solid #f0f0f0;
        }
        
        .recipe-content {
            padding: 1.5rem;
        }
        
        .recipe-description {
            color: #6c757d;
            font-size: 0.95rem;
            line-height: 1.5;
            margin-bottom: 1.5rem;
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
        
        /* Buttons */
        .stButton > button {
            background: white !important;
            color: #1a1a1a !important;
            border: 1px solid #e9ecef !important;
            padding: 0.6rem 1.5rem !important;
            font-weight: 500 !important;
            border-radius: 8px !important;
            transition: all 0.2s ease !important;
            font-size: 0.875rem !important;
        }
        
        .stButton > button:hover {
            background: #f8f9fa !important;
            border-color: #dee2e6 !important;
            transform: translateY(-1px) !important;
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
        
        /* Divider */
        hr {
            margin: 2rem 0 !important;
            border: none !important;
            height: 1px !important;
            background: #e9ecef !important;
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
        </style>
    """, unsafe_allow_html=True)
    
    # Add floating food emojis
    st.markdown("""
    <div class="floating-emoji" style="top: 10%; left: 5%; font-size: 80px; animation-delay: 0s;">🍳</div>
    <div class="floating-emoji" style="top: 20%; right: 10%; font-size: 60px; animation-delay: 2s;">🥗</div>
    <div class="floating-emoji" style="bottom: 30%; left: 15%; font-size: 70px; animation-delay: 4s;">🍝</div>
    <div class="floating-emoji" style="bottom: 20%; right: 5%; font-size: 90px; animation-delay: 1s;">🥘</div>
    """, unsafe_allow_html=True)
    
    # Celebration
    rain(emoji="✨", font_size=20, falling_speed=5, animation_length=1)
    
    # Logo at top center - using HTML with JavaScript for click handling
    st.markdown("""
        <div style="text-align: center; margin-bottom: 1.5rem; margin-top: -1rem;">
            <a href="#" onclick="window.location.reload(); return false;" style="text-decoration: none;">
                <div style="display: inline-flex; align-items: center; gap: 8px; cursor: pointer;">
                    <div style="
                        width: 32px;
                        height: 32px;
                        background: #25F4EE;
                        border-radius: 8px;
                        display: flex;
                        align-items: center;
                        justify-content: center;
                        font-size: 20px;
                    ">
                        👨‍🍳
                    </div>
                    <span style="
                        font-size: 1.5rem;
                        font-weight: 800;
                        color: #25F4EE;
                        font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
                        letter-spacing: -0.02em;
                    ">SnapChef</span>
                </div>
            </a>
        </div>
    """, unsafe_allow_html=True)
    
    # Title
    st.markdown("# Your Personalized Recipes ✨")
    st.markdown('<p class="subtitle">Crafted from the ingredients in your fridge</p>', unsafe_allow_html=True)
    
    # Ingredients section
    ingredients = st.session_state.get('detected_ingredients', [])
    if ingredients:
        st.markdown('<div class="ingredients-container">', unsafe_allow_html=True)
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
        st.markdown('</div>', unsafe_allow_html=True)
    
    # Recipes
    recipes = st.session_state.get('generated_recipes', [])
    
    if recipes:
        for idx, recipe in enumerate(recipes):
            # Recipe container
            st.markdown('<div class="recipe-container">', unsafe_allow_html=True)
            
            # Recipe header
            st.markdown('<div class="recipe-header">', unsafe_allow_html=True)
            st.markdown(f"### {recipe.get('name', 'Untitled Recipe')}")
            st.markdown(f'<p class="recipe-description">{recipe.get("description", "")}</p>', unsafe_allow_html=True)
            st.markdown('</div>', unsafe_allow_html=True)
            
            # Recipe content
            st.markdown('<div class="recipe-content">', unsafe_allow_html=True)
            
            # Metrics in columns
            metric_col1, metric_col2, metric_col3, metric_col4 = st.columns(4)
            
            with metric_col1:
                total_time = recipe.get('prep_time', 15) + recipe.get('cook_time', 15)
                st.metric("⏱️ Time", f"{total_time} min")
            
            with metric_col2:
                calories = recipe.get('nutrition', {}).get('calories', 'N/A')
                st.metric("🔥 Calories", str(calories))
            
            with metric_col3:
                servings = recipe.get('servings', 2)
                st.metric("👥 Servings", str(servings))
            
            with metric_col4:
                difficulty = recipe.get('difficulty', 'Easy')
                st.metric("📊 Level", difficulty)
            
            # Spacing
            st.markdown("<br>", unsafe_allow_html=True)
            
            # Action buttons
            btn_col1, btn_col2, btn_col3 = st.columns(3)
            
            with btn_col1:
                if st.button("🍳 Cook This Recipe", key=f"cook_{idx}", use_container_width=True):
                    st.success("✓ Recipe saved to your collection! +20 points")
                    add_points(20, "Cooked recipe")
            
            with btn_col2:
                if st.button("📱 Share Recipe", key=f"share_{idx}", use_container_width=True):
                    with st.expander("Share this recipe", expanded=True):
                        share_text = f"I just made {recipe.get('name', 'this amazing dish')} using SnapChef! 🍳✨"
                        st.code(share_text)
                        share_col1, share_col2 = st.columns(2)
                        with share_col1:
                            st.button("Share to TikTok", key=f"tiktok_{idx}", use_container_width=True)
                        with share_col2:
                            st.button("Share to Instagram", key=f"ig_{idx}", use_container_width=True)
            
            with btn_col3:
                steps_key = f"show_steps_{idx}"
                is_expanded = st.session_state.get(steps_key, False)
                
                if st.button(
                    "📋 Hide Steps" if is_expanded else "📋 View Steps", 
                    key=f"steps_{idx}", 
                    use_container_width=True
                ):
                    st.session_state[steps_key] = not is_expanded
                    st.rerun()
            
            # Recipe steps
            if st.session_state.get(f"show_steps_{idx}", False):
                with st.expander("Step-by-Step Instructions", expanded=True):
                    # Try different keys for instructions
                    steps = recipe.get('instructions', recipe.get('recipe', []))
                    if steps:
                        for i, step in enumerate(steps, 1):
                            st.markdown(f"**Step {i}:** {step}")
                            if i < len(steps):
                                st.markdown("---")
                    else:
                        st.info("Detailed steps will be available soon.")
            
            st.markdown('</div>', unsafe_allow_html=True)  # Close recipe-content
            st.markdown('</div>', unsafe_allow_html=True)  # Close recipe-container
            
            # Add spacing between recipes
            if idx < len(recipes) - 1:
                st.markdown("<br><br>", unsafe_allow_html=True)
    
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
    if st.session_state.get('raw_ingredient_response') or st.session_state.get('raw_recipe_response'):
        st.markdown("<br><br><hr>", unsafe_allow_html=True)
        
        # Small debug toggle at bottom
        if st.button("🔧 Show Debug Info", key="debug_toggle", help="View raw LLM responses for troubleshooting"):
            st.session_state.show_debug = not st.session_state.get('show_debug', False)
        
        if st.session_state.get('show_debug', False):
            st.markdown("### 🔍 Debug Information")
            
            # Show raw ingredient detection response
            if st.session_state.get('raw_ingredient_response'):
                with st.expander("📦 Raw Ingredient Detection Response", expanded=False):
                    st.code(st.session_state.raw_ingredient_response, language="json")
            
            # Show raw recipe generation response
            if st.session_state.get('raw_recipe_response'):
                with st.expander("🍳 Raw Recipe Generation Response", expanded=False):
                    st.code(st.session_state.raw_recipe_response, language="json")
            
            # Show detected ingredients as sent to recipe generation
            if ingredients:
                with st.expander("🧾 Ingredients Sent to Recipe Generation", expanded=False):
                    ingredient_names = [ing.get('name', str(ing)) if isinstance(ing, dict) else str(ing) for ing in ingredients]
                    st.json(ingredient_names)
            
            # Clear debug info button
            if st.button("🗑️ Clear Debug Info", key="clear_debug"):
                if 'raw_ingredient_response' in st.session_state:
                    del st.session_state.raw_ingredient_response
                if 'raw_recipe_response' in st.session_state:
                    del st.session_state.raw_recipe_response
                st.session_state.show_debug = False
                st.rerun()