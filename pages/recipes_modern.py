import streamlit as st
from utils.logo import render_logo

def show_recipes():
    # Modern recipes page
    st.markdown("""
        <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap');
        
        .main {
            background: #FAFAFA;
        }
        
        .recipes-header {
            background: white;
            padding: 20px;
            border-bottom: 1px solid #e5e5e5;
            margin-bottom: 20px;
        }
        
        .recipe-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
            gap: 20px;
            padding: 20px;
        }
        
        .recipe-card {
            background: white;
            border-radius: 16px;
            overflow: hidden;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
            transition: all 0.3s ease;
        }
        
        .recipe-card:hover {
            transform: translateY(-4px);
            box-shadow: 0 12px 24px rgba(0, 0, 0, 0.12);
        }
        
        .recipe-image {
            width: 100%;
            height: 200px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        
        .recipe-content {
            padding: 20px;
        }
        
        .recipe-title {
            font-size: 20px;
            font-weight: 700;
            color: #1a1a1a;
            margin-bottom: 8px;
        }
        
        .recipe-meta {
            display: flex;
            gap: 16px;
            color: #666;
            font-size: 14px;
            margin-top: 12px;
        }
        </style>
    """, unsafe_allow_html=True)
    
    # Header
    col1, col2, col3 = st.columns([1, 2, 1])
    
    with col1:
        if st.button("← Back"):
            st.session_state.current_page = 'home'
            st.rerun()
    
    with col2:
        st.markdown(render_logo("small"), unsafe_allow_html=True)
    
    st.markdown("### 📚 My Recipe Collection")
    
    # Tabs
    tab1, tab2, tab3 = st.tabs(["All Recipes", "Favorites", "Shared"])
    
    with tab1:
        # Recipe grid
        recipes = st.session_state.get('saved_recipes', [])
        
        if not recipes:
            st.info("No recipes yet! Snap your fridge to get started.")
            if st.button("📸 Snap Your Fridge", type="primary"):
                st.session_state.current_page = 'camera'
                st.rerun()
        else:
            # Display saved recipes
            for recipe in recipes:
                with st.container():
                    st.markdown(f"### {recipe.get('meal', {}).get('name', 'Recipe')}")
                    st.write(recipe.get('meal', {}).get('description', ''))
                    
                    col1, col2, col3 = st.columns(3)
                    with col1:
                        st.button("View", key=f"view_{recipe['id']}")
                    with col2:
                        st.button("Share", key=f"share_{recipe['id']}")
                    with col3:
                        st.button("Cook Again", key=f"cook_{recipe['id']}")
    
    with tab2:
        st.info("⭐ Your favorite recipes will appear here")
    
    with tab3:
        st.info("📱 Recipes you've shared will appear here")