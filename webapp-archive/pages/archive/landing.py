import streamlit as st
from utils.logo import render_logo
import time

def show_landing():
    # Modern CSS styling
    st.markdown("""
        <style>
        /* Import modern font */
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap');
        
        /* Global styles */
        * {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
        }
        
        /* Hero section */
        .hero-container {
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            position: relative;
            overflow: hidden;
        }
        
        /* Animated background */
        @keyframes float {
            0% { transform: translateY(0px) rotate(0deg); }
            50% { transform: translateY(-20px) rotate(180deg); }
            100% { transform: translateY(0px) rotate(360deg); }
        }
        
        .floating-shape {
            position: absolute;
            opacity: 0.1;
            animation: float 6s ease-in-out infinite;
        }
        
        /* Main content */
        .hero-content {
            text-align: center;
            z-index: 10;
            padding: 20px;
        }
        
        .hero-title {
            font-size: 72px;
            font-weight: 800;
            color: white;
            margin: 0;
            letter-spacing: -0.03em;
            line-height: 1.1;
        }
        
        .hero-subtitle {
            font-size: 24px;
            color: rgba(255, 255, 255, 0.9);
            margin: 20px 0 40px 0;
            font-weight: 400;
        }
        
        /* Main button */
        .snap-button {
            background: white;
            color: #764ba2;
            padding: 20px 60px;
            border-radius: 100px;
            font-size: 20px;
            font-weight: 700;
            border: none;
            cursor: pointer;
            transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.2);
            text-decoration: none;
            display: inline-block;
            margin: 20px 0;
        }
        
        .snap-button:hover {
            transform: translateY(-3px);
            box-shadow: 0 25px 50px rgba(0, 0, 0, 0.25);
        }
        
        /* Free uses indicator */
        .free-uses {
            background: rgba(255, 255, 255, 0.2);
            color: white;
            padding: 8px 20px;
            border-radius: 50px;
            font-size: 14px;
            font-weight: 600;
            margin: 10px 0;
            display: inline-block;
            backdrop-filter: blur(10px);
        }
        
        /* How it works link */
        .how-it-works {
            color: white;
            font-size: 16px;
            text-decoration: none;
            display: inline-flex;
            align-items: center;
            gap: 8px;
            margin-top: 40px;
            transition: all 0.3s ease;
            cursor: pointer;
        }
        
        .how-it-works:hover {
            transform: translateY(2px);
        }
        
        /* Down arrow animation */
        @keyframes bounce {
            0%, 100% { transform: translateY(0); }
            50% { transform: translateY(5px); }
        }
        
        .arrow-down {
            animation: bounce 2s infinite;
        }
        
        /* Features section */
        .features-section {
            background: #FAFAFA;
            padding: 100px 20px;
            text-align: center;
        }
        
        .section-title {
            font-size: 48px;
            font-weight: 800;
            color: #1a1a1a;
            margin-bottom: 60px;
            letter-spacing: -0.02em;
        }
        
        .feature-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 40px;
            max-width: 1200px;
            margin: 0 auto;
        }
        
        .feature-card {
            background: white;
            padding: 40px;
            border-radius: 20px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.08);
            transition: all 0.3s ease;
        }
        
        .feature-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.12);
        }
        
        .feature-icon {
            font-size: 48px;
            margin-bottom: 20px;
        }
        
        .feature-title {
            font-size: 24px;
            font-weight: 700;
            color: #1a1a1a;
            margin-bottom: 12px;
        }
        
        .feature-description {
            font-size: 16px;
            color: #666;
            line-height: 1.6;
        }
        
        /* Mobile responsive */
        @media (max-width: 768px) {
            .hero-title {
                font-size: 48px;
            }
            
            .hero-subtitle {
                font-size: 18px;
            }
            
            .snap-button {
                padding: 16px 40px;
                font-size: 18px;
            }
            
            .section-title {
                font-size: 36px;
            }
        }
        </style>
    """, unsafe_allow_html=True)
    
    # Logo
    logo_html = render_logo("hero", gradient=False)
    
    # Hero Section
    hero_html = f"""
    <div class="hero-container">
        <!-- Floating shapes for visual interest -->
        <div class="floating-shape" style="top: 10%; left: 5%; font-size: 80px;">🍳</div>
        <div class="floating-shape" style="top: 20%; right: 10%; font-size: 60px; animation-delay: 2s;">🥗</div>
        <div class="floating-shape" style="bottom: 20%; left: 15%; font-size: 70px; animation-delay: 4s;">🍝</div>
        <div class="floating-shape" style="bottom: 10%; right: 5%; font-size: 90px; animation-delay: 1s;">🥘</div>
        
        <div class="hero-content">
            <div style="margin-bottom: 40px;">
                {logo_html}
            </div>
            
            <h1 class="hero-title">Turn Your Fridge<br>Into Magic ✨</h1>
            <p class="hero-subtitle">AI-powered recipes from what you already have</p>
            
            <div class="free-uses">🎉 {st.session_state.free_uses} free snaps remaining</div>
            
            <div id="snap-button-container"></div>
            
            <div class="how-it-works" id="how-link">
                <span>See how the magic happens</span>
                <span class="arrow-down">↓</span>
            </div>
        </div>
    </div>
    """
    
    st.markdown(hero_html, unsafe_allow_html=True)
    
    # SnapChef button
    col1, col2, col3 = st.columns([1, 2, 1])
    with col2:
        if st.button("📸 SnapChef", key="main_snap", use_container_width=True):
            if st.session_state.free_uses > 0:
                st.session_state.free_uses -= 1
                st.session_state.current_page = 'camera'
                st.rerun()
            else:
                st.session_state.current_page = 'auth'
                st.rerun()
    
    # Features Section
    features_html = """
    <div class="features-section" id="features">
        <h2 class="section-title">How the Magic Happens ✨</h2>
        
        <div class="feature-grid">
            <div class="feature-card">
                <div class="feature-icon">📸</div>
                <div class="feature-title">Snap Your Fridge</div>
                <div class="feature-description">
                    Take a quick photo of your fridge or pantry. Our AI instantly recognizes all your ingredients.
                </div>
            </div>
            
            <div class="feature-card">
                <div class="feature-icon">🤖</div>
                <div class="feature-title">AI Magic</div>
                <div class="feature-description">
                    Our advanced AI analyzes your ingredients and creates personalized recipes just for you.
                </div>
            </div>
            
            <div class="feature-card">
                <div class="feature-icon">🍳</div>
                <div class="feature-title">Cook & Share</div>
                <div class="feature-description">
                    Get step-by-step recipes and share your creations with friends. Save money, reduce waste!
                </div>
            </div>
        </div>
    </div>
    """
    
    st.markdown(features_html, unsafe_allow_html=True)
    
    # JavaScript for smooth scrolling
    st.markdown("""
        <script>
        document.getElementById('how-link').addEventListener('click', function() {
            document.getElementById('features').scrollIntoView({ 
                behavior: 'smooth',
                block: 'start'
            });
        });
        </script>
    """, unsafe_allow_html=True)
    
    # Bottom CTA
    st.markdown("<div style='text-align: center; padding: 60px 20px; background: #f8f9fa;'>", unsafe_allow_html=True)
    
    col1, col2, col3 = st.columns([1, 2, 1])
    with col2:
        st.markdown("### Ready to reduce food waste?")
        st.markdown("Join thousands who are saving money and eating better")
        
        if st.button("🚀 Get Started Free", key="bottom_cta", use_container_width=True, type="primary"):
            if st.session_state.free_uses > 0:
                st.session_state.current_page = 'camera'
                st.rerun()
            else:
                st.session_state.current_page = 'auth'
                st.rerun()
    
    st.markdown("</div>", unsafe_allow_html=True)