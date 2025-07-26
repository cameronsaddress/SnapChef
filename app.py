import streamlit as st
import os
from dotenv import load_dotenv
from utils.database import init_db
from utils.session import init_session_state

# Load environment variables
load_dotenv()

# Page configuration
st.set_page_config(
    page_title="SnapChef ✨ - Turn Your Fridge into Meals",
    page_icon="📸",
    layout="wide",
    initial_sidebar_state="collapsed"
)

# Hide Streamlit UI elements for clean design
st.markdown("""
    <style>
    /* Hide Streamlit header and menu */
    #MainMenu {visibility: hidden;}
    header {visibility: hidden;}
    footer {visibility: hidden;}
    
    /* Remove padding */
    .main > div {
        padding-top: 0;
        padding-bottom: 0;
    }
    
    /* Custom scrollbar */
    ::-webkit-scrollbar {
        width: 8px;
        height: 8px;
    }
    
    ::-webkit-scrollbar-track {
        background: #f1f1f1;
    }
    
    ::-webkit-scrollbar-thumb {
        background: #888;
        border-radius: 4px;
    }
    
    ::-webkit-scrollbar-thumb:hover {
        background: #555;
    }
    </style>
""", unsafe_allow_html=True)

# Initialize database
init_db()

# Initialize session state
init_session_state()

# Track if user is authenticated
if 'authenticated' not in st.session_state:
    st.session_state.authenticated = False

# Track free uses
if 'free_uses' not in st.session_state:
    st.session_state.free_uses = 3  # Give 3 free uses

def main():
    # Check current page
    if 'current_page' not in st.session_state:
        st.session_state.current_page = 'landing'
    
    # Route to appropriate page
    if st.session_state.current_page == 'landing':
        from pages.landing_simple import show_landing
        show_landing()
    elif st.session_state.current_page == 'camera':
        from pages.camera_minimal_clean import show_camera
        show_camera()
    elif st.session_state.current_page == 'auth':
        from pages.auth import show_auth
        show_auth()
    elif st.session_state.current_page == 'home':
        from pages.home_modern import show_home
        show_home()
    elif st.session_state.current_page == 'recipes':
        from pages.recipes_modern import show_recipes
        show_recipes()
    elif st.session_state.current_page == 'profile':
        from pages.profile_modern import show_profile
        show_profile()
    elif st.session_state.current_page == 'results':
        from pages.results_professional import show_results
        show_results()

if __name__ == "__main__":
    main()