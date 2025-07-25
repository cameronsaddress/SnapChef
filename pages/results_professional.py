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
            padding-top: 2rem !important;
            max-width: 900px !important;
            margin: 0 auto !important;
        }
        
        /* Typography */
        h1 {
            color: white !important;
            text-align: center !important;
            font-size: 3rem !important;
            font-weight: 800 !important;
            margin-bottom: 0.5rem !important;
            letter-spacing: -0.02em !important;
        }
        
        h3 {
            color: #1a1a1a !important;
            font-size: 1.75rem !important;
            font-weight: 700 !important;
            margin-bottom: 0.5rem !important;
        }
        
        .subtitle {
            color: rgba(255, 255, 255, 0.9);
            text-align: center;
            font-size: 1.25rem;
            margin-bottom: 3rem;
            font-weight: 400;
        }
        
        /* Ingredients section */
        .ingredients-container {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(20px);
            border-radius: 24px;
            padding: 2rem;
            margin-bottom: 3rem;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.15);
        }
        
        .ingredients-header {
            color: #1a1a1a;
            font-size: 1.25rem;
            font-weight: 700;
            margin-bottom: 1.5rem;
            display: flex;
            align-items: center;
            gap: 0.5rem;
        }
        
        .ingredient-tag {
            display: inline-flex;
            align-items: center;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 0.5rem 1.25rem;
            border-radius: 100px;
            margin: 0.25rem;
            font-size: 0.95rem;
            font-weight: 600;
            box-shadow: 0 4px 12px rgba(102, 126, 234, 0.25);
            transition: all 0.3s ease;
        }
        
        .ingredient-tag:hover {
            transform: translateY(-2px);
            box-shadow: 0 6px 16px rgba(102, 126, 234, 0.35);
        }
        
        /* Recipe cards */
        .recipe-container {
            background: white;
            border-radius: 24px;
            overflow: hidden;
            margin-bottom: 2rem;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
            transition: all 0.3s ease;
        }
        
        .recipe-container:hover {
            transform: translateY(-4px);
            box-shadow: 0 30px 60px rgba(0, 0, 0, 0.15);
        }
        
        .recipe-header {
            background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
            padding: 2rem;
            border-bottom: 1px solid #e9ecef;
        }
        
        .recipe-content {
            padding: 2rem;
        }
        
        .recipe-description {
            color: #6c757d;
            font-size: 1.1rem;
            line-height: 1.6;
            margin-bottom: 2rem;
        }
        
        /* Metrics styling */
        [data-testid="metric-container"] {
            background: #f8f9fa;
            padding: 1rem;
            border-radius: 12px;
            text-align: center;
            transition: all 0.3s ease;
        }
        
        [data-testid="metric-container"]:hover {
            background: #e9ecef;
            transform: translateY(-2px);
        }
        
        [data-testid="metric-container"] label {
            color: #6c757d !important;
            font-size: 0.875rem !important;
            font-weight: 600 !important;
            text-transform: uppercase !important;
            letter-spacing: 0.05em !important;
        }
        
        [data-testid="metric-container"] [data-testid="metric-value"] {
            color: #1a1a1a !important;
            font-size: 1.5rem !important;
            font-weight: 700 !important;
        }
        
        /* Buttons */
        .stButton > button {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%) !important;
            color: white !important;
            border: none !important;
            padding: 0.75rem 2rem !important;
            font-weight: 600 !important;
            border-radius: 12px !important;
            transition: all 0.3s ease !important;
            box-shadow: 0 8px 20px rgba(102, 126, 234, 0.25) !important;
        }
        
        .stButton > button:hover {
            transform: translateY(-2px) !important;
            box-shadow: 0 12px 28px rgba(102, 126, 234, 0.35) !important;
        }
        
        /* Back button special styling */
        .back-btn button {
            background: rgba(255, 255, 255, 0.2) !important;
            border: 2px solid rgba(255, 255, 255, 0.3) !important;
            box-shadow: none !important;
        }
        
        .back-btn button:hover {
            background: rgba(255, 255, 255, 0.3) !important;
        }
        
        /* Recipe steps */
        .stExpander {
            background: #f8f9fa;
            border-radius: 12px;
            border: none !important;
            margin-top: 1rem;
        }
        
        .stExpander [data-testid="stExpanderToggleIcon"] {
            color: #667eea !important;
        }
        
        /* Success messages */
        .stSuccess {
            background: rgba(40, 167, 69, 0.1);
            border: 2px solid #28a745;
            border-radius: 12px;
            color: #28a745;
            font-weight: 600;
        }
        
        /* Divider */
        hr {
            margin: 3rem 0 !important;
            border: none !important;
            height: 1px !important;
            background: rgba(255, 255, 255, 0.2) !important;
        }
        
        /* Bottom CTA */
        .bottom-section {
            text-align: center;
            margin: 4rem 0 2rem;
        }
        
        /* Free uses notice */
        .premium-notice {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(20px);
            padding: 2rem;
            border-radius: 24px;
            text-align: center;
            margin-top: 3rem;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
        }
        
        .premium-notice h4 {
            color: #1a1a1a;
            font-size: 1.5rem;
            font-weight: 700;
            margin-bottom: 1rem;
        }
        
        .premium-notice p {
            color: #6c757d;
            font-size: 1.1rem;
            margin-bottom: 1.5rem;
        }
        </style>
    """, unsafe_allow_html=True)
    
    # Celebration
    rain(emoji="✨", font_size=20, falling_speed=5, animation_length=1)
    
    # Back button
    col1, col2, col3 = st.columns([1, 10, 1])
    with col1:
        with st.container():
            st.markdown('<div class="back-btn">', unsafe_allow_html=True)
            if st.button("← Back", key="back_btn"):
                st.session_state.current_page = 'camera'
                st.session_state.processing = False
                st.session_state.photo_taken = False
                st.rerun()
            st.markdown('</div>', unsafe_allow_html=True)
    
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
            ingredients_html += f'<span class="ingredient-tag">✓ {ing}</span>'
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
                    steps = recipe.get('recipe', [])
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
    col1, col2, col3 = st.columns([1, 3, 1])
    with col2:
        if st.button("📸 Snap Another Fridge", key="new_snap", use_container_width=True, type="primary"):
            # Reset states
            st.session_state.photo_taken = False
            st.session_state.processing = False
            st.session_state.photo = None
            st.session_state.detected_ingredients = []
            st.session_state.generated_recipes = []
            st.session_state.current_page = 'camera'
            st.rerun()
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