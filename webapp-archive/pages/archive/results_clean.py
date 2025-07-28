import streamlit as st
from streamlit_extras.let_it_rain import rain
from utils.session import add_points

def show_results():
    """Display recipe results with proper HTML rendering"""
    
    # Apply gradient background
    st.markdown("""
        <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap');
        
        /* Gradient background */
        .stApp {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        
        /* Container */
        .main .block-container {
            padding-top: 2rem !important;
            max-width: 800px !important;
            margin: 0 auto !important;
        }
        
        /* Typography */
        h1 {
            color: white !important;
            text-align: center !important;
            font-size: 2.5rem !important;
            margin-bottom: 0.5rem !important;
        }
        
        .subtitle {
            color: rgba(255, 255, 255, 0.9);
            text-align: center;
            font-size: 1.2rem;
            margin-bottom: 2rem;
        }
        
        /* Ingredients */
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
        
        /* Buttons */
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
        </style>
    """, unsafe_allow_html=True)
    
    # Celebration
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
    
    # Ingredients
    ingredients = st.session_state.get('detected_ingredients', [])
    if ingredients:
        st.markdown('<div class="ingredients-box">', unsafe_allow_html=True)
        st.markdown('<div class="ingredients-title">🔍 Detected Ingredients:</div>', unsafe_allow_html=True)
        
        ingredients_html = '<div>'
        for ing in ingredients:
            ingredients_html += f'<span class="ingredient-pill">{ing}</span>'
        ingredients_html += '</div>'
        
        st.markdown(ingredients_html, unsafe_allow_html=True)
        st.markdown('</div>', unsafe_allow_html=True)
    
    # Recipes
    recipes = st.session_state.get('generated_recipes', [])
    
    if recipes:
        for idx, recipe in enumerate(recipes):
            # Use Streamlit native components for recipe display
            with st.container():
                # Recipe header
                st.markdown(f"### {recipe.get('name', 'Untitled Recipe')}")
                st.markdown(recipe.get('description', ''))
                
                # Recipe stats in columns
                col1, col2, col3, col4 = st.columns(4)
                
                with col1:
                    st.metric(
                        "Time",
                        f"{recipe.get('prep_time', 15) + recipe.get('cook_time', 15)} min",
                        delta=None
                    )
                
                with col2:
                    calories = recipe.get('nutrition', {}).get('calories', 'N/A')
                    st.metric(
                        "Calories",
                        f"{calories}" if calories != 'N/A' else calories,
                        delta=None
                    )
                
                with col3:
                    st.metric(
                        "Servings",
                        recipe.get('servings', 2),
                        delta=None
                    )
                
                with col4:
                    st.metric(
                        "Difficulty",
                        recipe.get('difficulty', 'Easy'),
                        delta=None
                    )
                
                # Action buttons
                button_col1, button_col2, button_col3 = st.columns(3)
                
                with button_col1:
                    if st.button("🍳 Cook This", key=f"cook_{idx}"):
                        st.success("Recipe saved! +20 points 🎉")
                        add_points(20, "Cooked recipe")
                
                with button_col2:
                    if st.button("📱 Share", key=f"share_{idx}"):
                        with st.expander("Share Recipe"):
                            share_text = f"Check out this {recipe.get('name', 'amazing')} recipe from SnapChef! 🍳"
                            st.code(share_text)
                            share_col1, share_col2 = st.columns(2)
                            with share_col1:
                                st.button("TikTok", key=f"tiktok_{idx}")
                            with share_col2:
                                st.button("Instagram", key=f"ig_{idx}")
                
                with button_col3:
                    if st.button("📋 See Steps", key=f"steps_{idx}"):
                        steps_key = f"show_steps_{idx}"
                        st.session_state[steps_key] = not st.session_state.get(steps_key, False)
                        st.rerun()
                
                # Show steps if toggled
                if st.session_state.get(f"show_steps_{idx}", False):
                    with st.expander("Recipe Steps", expanded=True):
                        steps = recipe.get('recipe', [])
                        if steps:
                            for i, step in enumerate(steps, 1):
                                st.write(f"**Step {i}:** {step}")
                        else:
                            st.info("Detailed steps not available.")
                
                # Divider between recipes
                if idx < len(recipes) - 1:
                    st.divider()
    else:
        st.error("No recipes were generated. Please try again with a clearer photo.")
    
    # Bottom CTA
    st.markdown("<br><br>", unsafe_allow_html=True)
    
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
    
    # Free uses notice
    if st.session_state.get('free_uses', 3) <= 0:
        st.info("🎉 You've used all your free snaps! Sign up for unlimited access.")
        if st.button("Sign Up Free", key="signup_prompt", use_container_width=True):
            st.session_state.current_page = 'auth'
            st.rerun()