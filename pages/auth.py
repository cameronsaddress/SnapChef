import streamlit as st
from utils.logo import render_logo
import time

def show_auth():
    # Modern auth page styling
    st.markdown("""
        <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap');
        
        /* Auth container */
        .auth-container {
            max-width: 400px;
            margin: 0 auto;
            padding: 40px 20px;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            justify-content: center;
        }
        
        /* Form styling */
        .stTextInput > div > div > input {
            background: #f8f9fa;
            border: 2px solid transparent;
            border-radius: 12px;
            padding: 16px;
            font-size: 16px;
            transition: all 0.3s ease;
        }
        
        .stTextInput > div > div > input:focus {
            border-color: #667eea;
            box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
        }
        
        /* Button styling */
        .stButton > button {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            padding: 16px 32px;
            border-radius: 12px;
            font-size: 16px;
            font-weight: 600;
            width: 100%;
            transition: all 0.3s ease;
            box-shadow: 0 10px 20px rgba(102, 126, 234, 0.2);
        }
        
        .stButton > button:hover {
            transform: translateY(-2px);
            box-shadow: 0 15px 30px rgba(102, 126, 234, 0.3);
        }
        
        /* Tab styling */
        .stTabs [data-baseweb="tab-list"] {
            gap: 24px;
            background: transparent;
            border-bottom: 2px solid #e5e5e5;
        }
        
        .stTabs [data-baseweb="tab"] {
            background: transparent;
            border: none;
            color: #666;
            font-weight: 600;
            font-size: 18px;
            padding: 12px 0;
        }
        
        .stTabs [aria-selected="true"] {
            color: #667eea;
            border-bottom: 3px solid #667eea;
        }
        
        /* Social buttons */
        .social-button {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 12px;
            padding: 14px;
            border: 2px solid #e5e5e5;
            border-radius: 12px;
            background: white;
            color: #333;
            font-weight: 600;
            width: 100%;
            margin: 8px 0;
            transition: all 0.3s ease;
            cursor: pointer;
        }
        
        .social-button:hover {
            border-color: #667eea;
            background: #f8f9fa;
        }
        
        /* Divider */
        .auth-divider {
            display: flex;
            align-items: center;
            margin: 24px 0;
            color: #999;
            font-size: 14px;
        }
        
        .auth-divider::before,
        .auth-divider::after {
            content: '';
            flex: 1;
            height: 1px;
            background: #e5e5e5;
        }
        
        .auth-divider span {
            margin: 0 16px;
        }
        
        /* Benefits list */
        .benefits-list {
            background: #f8f9fa;
            border-radius: 16px;
            padding: 24px;
            margin: 24px 0;
        }
        
        .benefit-item {
            display: flex;
            align-items: center;
            gap: 12px;
            margin: 12px 0;
            color: #333;
        }
        
        .benefit-icon {
            color: #667eea;
            font-size: 20px;
        }
        </style>
    """, unsafe_allow_html=True)
    
    # Back button
    if st.button("← Back", key="back_auth"):
        st.session_state.current_page = 'landing'
        st.rerun()
    
    # Logo
    st.markdown(render_logo("medium"), unsafe_allow_html=True)
    
    # Auth tabs
    tab1, tab2 = st.tabs(["Sign In", "Sign Up"])
    
    with tab1:
        show_signin()
    
    with tab2:
        show_signup()

def show_signin():
    """Sign in form"""
    st.markdown("<h2 style='text-align: center; margin: 20px 0;'>Welcome Back!</h2>", unsafe_allow_html=True)
    
    # Social sign in
    st.markdown("""
        <div class="social-button">
            <span>🍎</span>
            <span>Continue with Apple</span>
        </div>
        <div class="social-button">
            <span>📧</span>
            <span>Continue with Google</span>
        </div>
    """, unsafe_allow_html=True)
    
    # Divider
    st.markdown('<div class="auth-divider"><span>or</span></div>', unsafe_allow_html=True)
    
    # Email/password form
    email = st.text_input("Email", placeholder="your@email.com", key="signin_email")
    password = st.text_input("Password", type="password", placeholder="••••••••", key="signin_password")
    
    col1, col2 = st.columns(2)
    with col1:
        remember = st.checkbox("Remember me")
    with col2:
        st.markdown("<p style='text-align: right;'><a href='#' style='color: #667eea; text-decoration: none;'>Forgot password?</a></p>", unsafe_allow_html=True)
    
    if st.button("Sign In", key="signin_button", use_container_width=True):
        with st.spinner("Signing in..."):
            time.sleep(1)
        st.session_state.authenticated = True
        st.session_state.username = email.split('@')[0]
        st.session_state.current_page = 'home'
        st.rerun()

def show_signup():
    """Sign up form"""
    st.markdown("<h2 style='text-align: center; margin: 20px 0;'>Join SnapChef!</h2>", unsafe_allow_html=True)
    
    # Benefits
    benefits_html = """
    <div class="benefits-list">
        <h4 style="margin-bottom: 16px;">✨ What you'll get:</h4>
        <div class="benefit-item">
            <span class="benefit-icon">♾️</span>
            <span>Unlimited recipe generation</span>
        </div>
        <div class="benefit-item">
            <span class="benefit-icon">💾</span>
            <span>Save and organize recipes</span>
        </div>
        <div class="benefit-item">
            <span class="benefit-icon">📊</span>
            <span>Track savings and nutrition</span>
        </div>
        <div class="benefit-item">
            <span class="benefit-icon">🏆</span>
            <span>Join challenges and win prizes</span>
        </div>
    </div>
    """
    st.markdown(benefits_html, unsafe_allow_html=True)
    
    # Form fields
    name = st.text_input("Name", placeholder="John Doe", key="signup_name")
    email = st.text_input("Email", placeholder="your@email.com", key="signup_email")
    password = st.text_input("Password", type="password", placeholder="Create a password", key="signup_password")
    
    # Terms
    terms = st.checkbox("I agree to the Terms of Service and Privacy Policy")
    
    if st.button("Create Account", key="signup_button", use_container_width=True, disabled=not terms):
        with st.spinner("Creating your account..."):
            time.sleep(1)
        st.session_state.authenticated = True
        st.session_state.username = name
        st.session_state.free_uses = 10  # Give new users more free uses
        st.success("🎉 Account created! Welcome to SnapChef!")
        time.sleep(1)
        st.session_state.current_page = 'home'
        st.rerun()
    
    # Social signup
    st.markdown('<div class="auth-divider"><span>or</span></div>', unsafe_allow_html=True)
    
    st.markdown("""
        <div class="social-button">
            <span>🍎</span>
            <span>Sign up with Apple</span>
        </div>
        <div class="social-button">
            <span>📧</span>
            <span>Sign up with Google</span>
        </div>
    """, unsafe_allow_html=True)