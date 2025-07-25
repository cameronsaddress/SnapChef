import streamlit as st
from streamlit_extras.let_it_rain import rain
from utils.session import add_points

def show_results():
    """Display recipe results with gradient background"""
    
    # Consistent gradient background
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
        
        /* Results container */
        .results-container {
            max-width: 800px;
            margin: 0 auto;
            padding: 2rem;
        }
        
        /* Title styling */
        .results-title {
            color: white;
            font-size: 2.5rem;
            font-weight: 800;
            text-align: center;
            margin-bottom: 1rem;
        }
        
        .results-subtitle {
            color: rgba(255, 255, 255, 0.9);
            font-size: 1.2rem;
            text-align: center;
            margin-bottom: 2rem;
        }
        
        /* Ingredients section */
        .ingredients-section {
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
            transition: all 0.3s ease;
        }
        
        .recipe-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 15px 40px rgba(0, 0, 0, 0.25);
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
        }
        
        .stat-item {
            display: flex;
            align-items: center;
            gap: 0.5rem;
            color: #666;
            font-size: 0.9rem;
        }
        
        /* Action buttons */
        .action-button {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            padding: 0.75rem 2rem;
            border-radius: 50px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s ease;
            margin-right: 1rem;
            margin-top: 1rem;
        }
        
        .action-button:hover {
            transform: translateY(-2px);
            box-shadow: 0 10px 20px rgba(102, 126, 234, 0.3);
        }
        
        .secondary-button {
            background: #f0f0f0;
            color: #333;
            border: none;
            padding: 0.75rem 2rem;
            border-radius: 50px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s ease;
            margin-top: 1rem;
        }
        
        .secondary-button:hover {
            background: #e5e5e5;
        }
        
        /* Bottom action */
        .bottom-action {
            text-align: center;
            margin-top: 3rem;
        }
        
        .new-snap-button {
            background: rgba(255, 255, 255, 0.2);
            backdrop-filter: blur(10px);
            color: white;
            border: 2px solid rgba(255, 255, 255, 0.3);
            padding: 1rem 3rem;
            border-radius: 50px;
            font-size: 1.1rem;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s ease;
        }
        
        .new-snap-button:hover {
            background: rgba(255, 255, 255, 0.3);
            transform: translateY(-2px);
        }
        
        /* Override Streamlit button styles */
        .stButton > button {
            width: auto !important;
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
            align-items: start;
        }
        
        .step-number {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            width: 30px;
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
        }
        </style>
    """, unsafe_allow_html=True)
    
    # Celebration animation
    rain(emoji="✨", font_size=20, falling_speed=5, animation_length=2)
    
    # Back button
    if st.button("← Back", key="back_btn"):
        st.session_state.current_page = 'camera'
        st.session_state.processing = False
        st.session_state.photo_taken = False
        st.rerun()
    
    # Results container
    st.markdown('<div class="results-container">', unsafe_allow_html=True)
    
    # Title
    st.markdown('<h1 class="results-title">Your Personalized Recipes ✨</h1>', unsafe_allow_html=True)
    st.markdown('<p class="results-subtitle">Based on what we found in your fridge</p>', unsafe_allow_html=True)
    
    # Show detected ingredients
    ingredients = st.session_state.get('detected_ingredients', [])
    if ingredients:
        st.markdown("""
        <div class="ingredients-section">
            <div class="ingredients-title">🔍 Detected Ingredients:</div>
        """, unsafe_allow_html=True)
        
        ingredients_html = ""
        for ing in ingredients:
            ingredients_html += f'<span class="ingredient-pill">{ing}</span>'
        
        st.markdown(ingredients_html, unsafe_allow_html=True)
        st.markdown('</div>', unsafe_allow_html=True)
    
    # Display recipes
    recipes = st.session_state.get('generated_recipes', [])
    
    if recipes:
        for idx, recipe in enumerate(recipes):
            # Sanitize recipe data
            recipe_name = str(recipe.get('name', 'Untitled Recipe')).replace('<', '&lt;').replace('>', '&gt;')
            recipe_desc = str(recipe.get('description', '')).replace('<', '&lt;').replace('>', '&gt;')
            
            # Recipe card
            st.markdown(f"""
            <div class="recipe-card">
                <h2 class="recipe-title">{recipe_name}</h2>
                <p class="recipe-description">{recipe_desc}</p>
                
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
            </div>
            """, unsafe_allow_html=True)
            
            # Action buttons for each recipe
            col1, col2, col3 = st.columns(3)
            
            with col1:
                if st.button("🍳 Cook This", key=f"cook_{idx}"):
                    st.success("Recipe saved! +20 points 🎉")
                    add_points(20, "Cooked recipe")
                    # Here you would save the recipe to the user's collection
            
            with col2:
                if st.button("📱 Share", key=f"share_{idx}"):
                    st.info("Share feature coming soon!")
            
            with col3:
                if st.button("📋 See Steps", key=f"steps_{idx}"):
                    # Toggle showing steps
                    steps_key = f"show_steps_{idx}"
                    st.session_state[steps_key] = not st.session_state.get(steps_key, False)
                    st.rerun()
            
            # Show recipe steps if toggled
            if st.session_state.get(f"show_steps_{idx}", False):
                st.markdown('<div class="recipe-steps">', unsafe_allow_html=True)
                steps = recipe.get('recipe', [])
                if steps:
                    for i, step in enumerate(steps, 1):
                        st.markdown(f"""
                        <div class="step-item">
                            <div class="step-number">{i}</div>
                            <div class="step-text">{step}</div>
                        </div>
                        """, unsafe_allow_html=True)
                st.markdown('</div>', unsafe_allow_html=True)
    else:
        st.error("No recipes were generated. Please try again with a clearer photo.")
    
    # Bottom action - New snap
    st.markdown('<div class="bottom-action">', unsafe_allow_html=True)
    
    col1, col2, col3 = st.columns([1, 2, 1])
    with col2:
        if st.button("📸 Snap Another Fridge", key="new_snap", use_container_width=True):
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
    
    # Check free uses
    if st.session_state.get('free_uses', 3) <= 0:
        st.markdown("""
        <div style="text-align: center; margin-top: 2rem;">
            <div style="background: rgba(255, 255, 255, 0.1); backdrop-filter: blur(10px); 
                        padding: 1.5rem; border-radius: 20px; color: white;">
                <p style="font-size: 1.1rem; margin-bottom: 1rem;">
                    🎉 You've used all your free snaps!
                </p>
                <p style="opacity: 0.9;">Sign up for unlimited access and save your recipes</p>
            </div>
        </div>
        """, unsafe_allow_html=True)
        
        col1, col2, col3 = st.columns([1, 2, 1])
        with col2:
            if st.button("Sign Up Free", key="signup_prompt", use_container_width=True):
                st.session_state.current_page = 'auth'
                st.rerun()