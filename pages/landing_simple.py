import streamlit as st
from utils.logo import render_logo
import time
from components.topbar import render_topbar, add_floating_food_animation

def show_landing():
    # Render top bar
    render_topbar()
    
    # Add floating food animation
    add_floating_food_animation()
    
    # Apply custom CSS
    st.markdown("""
        <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap');
        
        .stApp {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        
        .main > div {
            padding-top: 2rem;
        }
        
        h1 {
            color: white !important;
            font-size: 4rem !important;
            font-weight: 800 !important;
            text-align: center !important;
            line-height: 1.1 !important;
            margin-top: 2rem !important;
        }
        
        h2 {
            color: white !important;
            font-size: 1.5rem !important;
            font-weight: 400 !important;
            text-align: center !important;
            opacity: 0.9;
        }
        
        h3 {
            color: white !important;
            font-size: 2.5rem !important;
            font-weight: 800 !important;
            text-align: center !important;
            margin: 3rem 0 !important;
        }
        
        .stButton > button {
            background: white !important;
            color: #764ba2 !important;
            border: none !important;
            padding: 1.25rem 3.75rem !important;
            font-size: 1.25rem !important;
            font-weight: 700 !important;
            border-radius: 50px !important;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.2) !important;
            transition: all 0.3s ease !important;
            margin: 1rem auto !important;
        }
        
        .stButton > button:hover {
            transform: translateY(-3px) !important;
            box-shadow: 0 25px 50px rgba(0, 0, 0, 0.25) !important;
        }
        
        .feature-container {
            background: white;
            padding: 2rem;
            border-radius: 1rem;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.1);
            margin: 1rem 0;
            text-align: center;
        }
        
        .feature-icon {
            font-size: 3rem;
            margin-bottom: 1rem;
        }
        
        .feature-title {
            font-size: 1.5rem;
            font-weight: 700;
            color: #1a1a1a;
            margin-bottom: 0.5rem;
        }
        
        .feature-description {
            color: #666;
            line-height: 1.6;
        }
        
        .free-uses-badge {
            background: rgba(255, 255, 255, 0.2);
            color: white;
            padding: 0.5rem 1.25rem;
            border-radius: 25px;
            font-weight: 600;
            display: inline-block;
            backdrop-filter: blur(10px);
            margin: 1rem 0;
        }
        
        /* Center everything */
        .block-container {
            max-width: 1200px;
            padding: 0 1rem;
        }
        
        /* Bottom section background */
        .bottom-cta {
            background: #f8f9fa;
            padding: 3rem 1rem;
            border-radius: 1rem;
            margin-top: 3rem;
            text-align: center;
        }
        
        .bottom-cta h3 {
            color: #1a1a1a !important;
            margin-bottom: 0.5rem !important;
        }
        
        .bottom-cta p {
            color: #666;
            font-size: 1.1rem;
            margin-bottom: 1.5rem;
        }
        
        @media (max-width: 768px) {
            h1 {
                font-size: 3rem !important;
            }
            
            h2 {
                font-size: 1.25rem !important;
            }
            
            .stButton > button {
                padding: 1rem 2rem !important;
                font-size: 1.1rem !important;
            }
        }
        </style>
    """, unsafe_allow_html=True)
    
    # Logo - positioned 5px below topbar
    st.markdown('<div style="margin-top: 5px;">', unsafe_allow_html=True)
    st.markdown(render_logo("hero", gradient=True), unsafe_allow_html=True)
    st.markdown('</div>', unsafe_allow_html=True)
    
    # Hero Title
    st.markdown("<h1>Meal Magic!</h1>", unsafe_allow_html=True)
    
    # Subtitle
    st.markdown("<h2>AI-powered recipes from what you already have</h2>", unsafe_allow_html=True)
    
    # Free uses indicator
    st.markdown(f'<div style="text-align: center;"><span class="free-uses-badge">Hey Friend, Here\'s {st.session_state.free_uses} free snaps on us! 👇</span></div>', unsafe_allow_html=True)
    
    # Main CTA Button with styled logo
    col1, col2, col3 = st.columns([1, 2, 1])
    with col2:
        # Custom CSS for gradient text and button styling
        st.markdown("""
        <style>
        /* Button container styling */
        div[data-testid="column"]:nth-child(2) .stButton > button {
            background: white !important;
            border: none !important;
            padding: 1.25rem 3rem !important;
            border-radius: 50px !important;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.2) !important;
            transition: all 0.3s ease !important;
            font-size: 1.25rem !important;
            font-weight: 800 !important;
        }
        
        div[data-testid="column"]:nth-child(2) .stButton > button:hover {
            transform: translateY(-3px) !important;
            box-shadow: 0 25px 50px rgba(0, 0, 0, 0.25) !important;
        }
        
        /* Style the button text with single color */
        div[data-testid="column"]:nth-child(2) .stButton > button span {
            color: #25F4EE !important;
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
            letter-spacing: -0.02em;
        }
        </style>
        """, unsafe_allow_html=True)
        
        # Use native icon parameter with emoji
        if st.button("SnapChef", key="main_snap", use_container_width=True, icon="👨‍🍳"):
            if st.session_state.free_uses > 0:
                st.session_state.free_uses -= 1
                st.session_state.current_page = 'camera'
                st.rerun()
            else:
                st.session_state.current_page = 'auth'
                st.rerun()
    
    # Some spacing
    st.markdown("<br><br><br>", unsafe_allow_html=True)
    
    # Features Section
    st.markdown("<h3>How the Magic Happens ✨</h3>", unsafe_allow_html=True)
    
    # Feature cards using columns
    col1, col2, col3 = st.columns(3)
    
    with col1:
        st.markdown("""
        <div class="feature-container">
            <div class="feature-icon">📸</div>
            <div class="feature-title">Snap Your Fridge</div>
            <div class="feature-description">
                Take a quick photo of your fridge or pantry. In less than a minute, our AI recognizes all your ingredients.
            </div>
        </div>
        """, unsafe_allow_html=True)
    
    with col2:
        st.markdown("""
        <div class="feature-container">
            <div class="feature-icon">🤖</div>
            <div class="feature-title">AI Magic</div>
            <div class="feature-description">
                Our advanced AI analyzes your ingredients and creates personalized recipes from the stuff you actually have.
            </div>
        </div>
        """, unsafe_allow_html=True)
    
    with col3:
        st.markdown("""
        <div class="feature-container">
            <div class="feature-icon">🍳</div>
            <div class="feature-title">Cook & Share</div>
            <div class="feature-description">
                Get step-by-step recipes and share your creations with friends. No more wasted groceries, no more "what's for dinner?".
            </div>
        </div>
        """, unsafe_allow_html=True)
    
    # Some spacing
    st.markdown("<br><br>", unsafe_allow_html=True)
    
    # Bottom CTA
    st.markdown("""
    <div class="bottom-cta">
        <h3>Ready to eat like a king?</h3>
        <p>Join thousands who are saving money and eating better</p>
    </div>
    """, unsafe_allow_html=True)
    
    col1, col2, col3 = st.columns([1, 2, 1])
    with col2:
        # Use native icon parameter for bottom button
        if st.button("Get Started Free", key="bottom_cta", use_container_width=True, icon="🚀"):
            if st.session_state.free_uses > 0:
                st.session_state.current_page = 'camera'
                st.rerun()
            else:
                st.session_state.current_page = 'auth'
                st.rerun()
    
    # Add some floating emojis for visual interest
    # Floating food is now handled by add_floating_food_animation()