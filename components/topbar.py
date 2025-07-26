"""
Shared top bar component for all pages
"""
import streamlit as st

def render_topbar():
    """Render the sticky top bar with SnapChef logo"""
    st.markdown("""
        <style>
        /* Sticky top bar */
        .top-bar {
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            width: 100vw;
            height: 60px;
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
            z-index: 99999;
            display: flex;
            align-items: center;
            padding: 0 2rem;
            box-sizing: border-box;
        }
        
        /* Ensure topbar breaks out of any parent transforms */
        @media screen {
            .top-bar {
                position: fixed !important;
                transform: translateZ(0);
            }
        }
        
        /* Logo container */
        .logo-container {
            display: flex;
            align-items: center;
            gap: 0.75rem;
            cursor: pointer;
            text-decoration: none;
            transition: opacity 0.2s;
        }
        
        .logo-container:hover {
            opacity: 0.8;
        }
        
        /* Logo icon */
        .logo-icon {
            width: 36px;
            height: 36px;
            background: #25F4EE;
            border-radius: 10px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 24px;
        }
        
        /* Logo text */
        .logo-text {
            font-size: 1.5rem;
            font-weight: 800;
            color: #25F4EE;
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
            letter-spacing: -0.02em;
            margin: 0;
        }
        
        /* Add padding to main content to account for fixed header */
        .main .block-container {
            padding-top: 70px !important;
        }
        
        /* Mobile adjustments */
        @media (max-width: 768px) {
            .top-bar {
                padding: 0 1rem;
            }
            
            .logo-text {
                font-size: 1.25rem;
            }
        }
        </style>
        
        <div class="top-bar">
            <div class="logo-container" id="logo-nav">
                <div class="logo-icon">👨‍🍳</div>
                <div class="logo-text">SnapChef ✨</div>
            </div>
        </div>
        
        <script>
        // Make the entire logo clickable
        document.addEventListener('DOMContentLoaded', function() {
            const logoNav = document.getElementById('logo-nav');
            if (logoNav) {
                logoNav.style.cursor = 'pointer';
                logoNav.addEventListener('click', function() {
                    // Navigate to home by triggering a page reload with landing page
                    const currentUrl = new URL(window.location);
                    currentUrl.searchParams.set('page', 'landing');
                    window.location.href = currentUrl.toString();
                });
            }
        });
        </script>
    """, unsafe_allow_html=True)

def add_floating_food_animation():
    """Add floating food animation that works on all pages"""
    st.markdown("""
        <style>
        /* Floating food animation */
        @keyframes float {
            0% { 
                transform: translateY(0px) rotate(0deg); 
                opacity: 0.03;
            }
            50% { 
                transform: translateY(-20px) rotate(180deg); 
                opacity: 0.05;
            }
            100% { 
                transform: translateY(0px) rotate(360deg); 
                opacity: 0.03;
            }
        }
        
        .floating-emoji {
            position: fixed;
            animation: float 6s ease-in-out infinite;
            pointer-events: none;
            z-index: 1;  /* Behind content but above background */
            opacity: 0.03;  /* Start with low opacity */
        }
        
        /* Ensure content is above floating items */
        .main .block-container {
            position: relative;
            z-index: 10;
        }
        
        /* All Streamlit elements above floating items */
        .stButton, .stTextInput, .stSelectbox, .stTextArea, .stMetric, .stExpander {
            position: relative;
            z-index: 10;
        }
        </style>
        
        <div class="floating-emoji" style="top: 10%; left: 5%; font-size: 80px; animation-delay: 0s;">🍳</div>
        <div class="floating-emoji" style="top: 20%; right: 10%; font-size: 60px; animation-delay: 2s;">🥗</div>
        <div class="floating-emoji" style="bottom: 30%; left: 15%; font-size: 70px; animation-delay: 4s;">🍝</div>
        <div class="floating-emoji" style="bottom: 20%; right: 5%; font-size: 90px; animation-delay: 1s;">🥘</div>
        <div class="floating-emoji" style="top: 50%; left: 10%; font-size: 65px; animation-delay: 3s;">🍕</div>
        <div class="floating-emoji" style="top: 70%; right: 15%; font-size: 75px; animation-delay: 5s;">🌮</div>
    """, unsafe_allow_html=True)