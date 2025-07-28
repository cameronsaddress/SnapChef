import streamlit as st
from streamlit_extras.let_it_rain import rain
from utils.session import add_points

def show_results():
    """Display recipe results with gradient background"""
    
    # Consistent gradient background and styling
    st.markdown("""
        <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap');
        
        /* Gradient background */
        .stApp {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        
        /* Remove default padding */
        .main .block-container {
            padding-top: 2rem !important;
            max-width: 800px !important;
            margin: 0 auto !important;
        }
        
        /* Back button */
        .stButton > button {
            background: rgba(255, 255, 255, 0.2) !important;
            border: 2px solid rgba(255, 255, 255, 0.3) !important;
            color: white !important;
            font-weight: 600 !important;
            backdrop-filter: blur(10px) !important;
        }
        
        /* Title styling */
        h1 {
            color: white !important;
            text-align: center !important;
            font-size: 2.5rem !important;
            margin-bottom: 0.5rem !important;
        }
        
        h2 {
            color: #1a1a1a !important;
            font-size: 1.8rem !important;
            margin-bottom: 0.5rem !important;
        }
        
        /* Subtitle */
        .subtitle {
            color: rgba(255, 255, 255, 0.9);
            text-align: center;
            font-size: 1.2rem;
            margin-bottom: 2rem;
        }
        
        /* Ingredients section */
        .ingredients-box {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(20px);
            border-radius: 20px;
            padding: 1.5rem;
            margin-bottom: 2rem;
        }
        
        .ingredients-title {
            color: white;
            font-size: 1.2rem;
            font-weight: 600;
            margin-bottom: 1rem;
        }
        
        .ingredient-pill {
            display: inline-block;
            background: rgba(255, 255, 255, 0.2);
            color: white;
            padding: 0.5rem 1rem;
            border-radius: 20px;
            margin: 0.25rem;
            font-size: 0.9rem;
            font-weight: 500;
        }
        
        /* Recipe cards */
        .recipe-card {
            background: white;
            border-radius: 20px;
            padding: 2rem;
            margin-bottom: 1.5rem;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.2);
        }
        
        .recipe-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 15px 40px rgba(0, 0, 0, 0.25);
            transition: all 0.3s ease;
        }
        
        .recipe-title {
            font-size: 1.8rem;
            font-weight: 700;
            color: #1a1a1a;
            margin-bottom: 0.5rem;
        }
        
        .recipe-description {
            color: #666;
            font-size: 1rem;
            line-height: 1.5;
            margin-bottom: 1rem;
        }
        
        .recipe-stats {
            display: flex;
            flex-wrap: wrap;
            gap: 1.5rem;
            margin: 1rem 0;
            padding: 1rem 0;
            border-top: 1px solid #f0f0f0;
        }
        
        .stat-item {
            display: flex;
            align-items: center;
            gap: 0.5rem;
            color: #666;
            font-size: 0.9rem;
        }
        
        /* Recipe steps */
        .recipe-steps {
            margin-top: 1.5rem;
            padding-top: 1.5rem;
            border-top: 1px solid #e5e5e5;
        }
        
        .step-item {
            display: flex;
            gap: 1rem;
            margin-bottom: 1rem;
            align-items: flex-start;
        }
        
        .step-number {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-width: 30px;
            height: 30px;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: 600;
            flex-shrink: 0;
        }
        
        .step-text {
            color: #333;
            line-height: 1.6;
            flex: 1;
        }
        
        /* Bottom CTA */
        .bottom-cta {
            text-align: center;
            margin: 3rem 0;
        }
        
        /* Free uses notice */
        .free-uses-notice {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            padding: 1.5rem;
            border-radius: 20px;
            color: white;
            text-align: center;
            margin-top: 2rem;
        }
        </style>
    """, unsafe_allow_html=True)
    
    # Celebration animation
    rain(emoji="✨", font_size=20, falling_speed=5, animation_length=2)
    
    # Back button
    col1, col2, col3 = st.columns([1, 10, 1])
    with col1:
        if st.button("← Back", key="back_btn"):
            st.session_state.current_page = 'camera'
            st.session_state.processing = False
            st.session_state.photo_taken = False
            st.rerun()
    
    # Title
    st.markdown("# Your Personalized Recipes ✨")
    st.markdown('<p class="subtitle">Based on what we found in your fridge</p>', unsafe_allow_html=True)
    
    # Show detected ingredients
    ingredients = st.session_state.get('detected_ingredients', [])
    if ingredients:
        st.markdown('<div class="ingredients-box">', unsafe_allow_html=True)
        st.markdown('<div class="ingredients-title">🔍 Detected Ingredients:</div>', unsafe_allow_html=True)
        
        # Create ingredient pills with proper spacing
        ingredients_html = '<div>'
        for ing in ingredients:
            ingredients_html += f'<span class="ingredient-pill">{ing}</span>'
        ingredients_html += '</div>'
        
        st.markdown(ingredients_html, unsafe_allow_html=True)
        st.markdown('</div>', unsafe_allow_html=True)
    
    # Display recipes
    recipes = st.session_state.get('generated_recipes', [])
    
    if recipes:
        for idx, recipe in enumerate(recipes):
            # Create recipe card container
            with st.container():
                # Recipe card HTML
                recipe_html = f"""
                <div class="recipe-card">
                    <div class="recipe-title">{recipe.get('name', 'Untitled Recipe')}</div>
                    <div class="recipe-description">{recipe.get('description', '')}</div>
                    
                    <div class="recipe-stats">
                        <div class="stat-item">
                            <span>⏱️</span>
                            <span>{recipe.get('prep_time', 15) + recipe.get('cook_time', 15)} minutes</span>
                        </div>
                        <div class="stat-item">
                            <span>🔥</span>
                            <span>{recipe.get('nutrition', {}).get('calories', 'N/A')} calories</span>
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
                """
                
                # Add steps if toggled
                if st.session_state.get(f"show_steps_{idx}", False):
                    recipe_html += '<div class="recipe-steps">'
                    steps = recipe.get('recipe', [])
                    if steps:
                        for i, step in enumerate(steps, 1):
                            recipe_html += f"""
                            <div class="step-item">
                                <div class="step-number">{i}</div>
                                <div class="step-text">{step}</div>
                            </div>
                            """
                    recipe_html += '</div>'
                
                recipe_html += '</div>'
                st.markdown(recipe_html, unsafe_allow_html=True)
                
                # Action buttons
                col1, col2, col3 = st.columns(3)
                
                with col1:
                    if st.button("🍳 Cook This", key=f"cook_{idx}"):
                        st.success("Recipe saved! +20 points 🎉")
                        add_points(20, "Cooked recipe")
                
                with col2:
                    if st.button("📱 Share", key=f"share_{idx}"):
                        with st.expander("Share Recipe"):
                            st.code(f"Check out this {recipe.get('name', 'amazing')} recipe from SnapChef! 🍳")
                            col_a, col_b = st.columns(2)
                            with col_a:
                                st.button("TikTok", key=f"tiktok_{idx}")
                            with col_b:
                                st.button("Instagram", key=f"ig_{idx}")
                
                with col3:
                    button_text = "📋 Hide Steps" if st.session_state.get(f"show_steps_{idx}", False) else "📋 See Steps"
                    if st.button(button_text, key=f"steps_{idx}"):
                        steps_key = f"show_steps_{idx}"
                        st.session_state[steps_key] = not st.session_state.get(steps_key, False)
                        st.rerun()
                
                st.markdown("<br>", unsafe_allow_html=True)
    else:
        st.error("No recipes were generated. Please try again with a clearer photo.")
    
    # Bottom CTA
    st.markdown('<div class="bottom-cta">', unsafe_allow_html=True)
    col1, col2, col3 = st.columns([1, 2, 1])
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
    
    # Check free uses
    if st.session_state.get('free_uses', 3) <= 0:
        st.markdown("""
        <div class="free-uses-notice">
            <p style="font-size: 1.1rem; margin-bottom: 1rem;">
                🎉 You've used all your free snaps!
            </p>
            <p style="opacity: 0.9;">Sign up for unlimited access and save your recipes</p>
        </div>
        """, unsafe_allow_html=True)
        
        col1, col2, col3 = st.columns([1, 2, 1])
        with col2:
            if st.button("Sign Up Free", key="signup_prompt", use_container_width=True):
                st.session_state.current_page = 'auth'
                st.rerun()