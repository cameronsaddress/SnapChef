import streamlit as st
from utils.logo import render_logo

def show_profile():
    # Modern profile page
    st.markdown("""
        <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap');
        
        .main {
            background: #FAFAFA;
        }
        
        .profile-header {
            background: white;
            padding: 40px;
            text-align: center;
            border-bottom: 1px solid #e5e5e5;
        }
        
        .profile-avatar {
            width: 120px;
            height: 120px;
            border-radius: 60px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            display: inline-flex;
            align-items: center;
            justify-content: center;
            font-size: 48px;
            color: white;
            margin-bottom: 20px;
        }
        
        .profile-name {
            font-size: 28px;
            font-weight: 700;
            color: #1a1a1a;
            margin-bottom: 8px;
        }
        
        .profile-email {
            color: #666;
            font-size: 16px;
        }
        
        .settings-section {
            background: white;
            padding: 24px;
            margin: 20px 0;
            border-radius: 16px;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
        }
        
        .settings-item {
            padding: 16px 0;
            border-bottom: 1px solid #f0f0f0;
            display: flex;
            justify-content: space-between;
            align-items: center;
            cursor: pointer;
            transition: all 0.3s ease;
        }
        
        .settings-item:hover {
            background: #f8f9fa;
            margin: 0 -24px;
            padding-left: 24px;
            padding-right: 24px;
        }
        
        .settings-item:last-child {
            border-bottom: none;
        }
        
        .logout-button {
            background: #ff4757;
            color: white;
            padding: 12px 32px;
            border-radius: 12px;
            border: none;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s ease;
        }
        
        .logout-button:hover {
            background: #ff3838;
            transform: translateY(-1px);
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
    
    # Profile info
    profile_html = f"""
    <div class="profile-header">
        <div class="profile-avatar">{st.session_state.get('username', 'U')[0].upper()}</div>
        <div class="profile-name">{st.session_state.get('username', 'User')}</div>
        <div class="profile-email">{st.session_state.get('username', 'user')}@snapchef.com</div>
    </div>
    """
    st.markdown(profile_html, unsafe_allow_html=True)
    
    # Stats
    col1, col2, col3 = st.columns(3)
    with col1:
        st.metric("Recipes Created", "12")
    with col2:
        st.metric("Money Saved", "$127")
    with col3:
        st.metric("Points", st.session_state.get('user_points', 0))
    
    # Settings sections
    st.markdown("""
    <div class="settings-section">
        <h3>Account Settings</h3>
        <div class="settings-item">
            <span>✉️ Email Notifications</span>
            <span>→</span>
        </div>
        <div class="settings-item">
            <span>🔒 Privacy Settings</span>
            <span>→</span>
        </div>
        <div class="settings-item">
            <span>🥗 Dietary Preferences</span>
            <span>→</span>
        </div>
        <div class="settings-item">
            <span>💳 Subscription</span>
            <span>Free →</span>
        </div>
    </div>
    
    <div class="settings-section">
        <h3>Support</h3>
        <div class="settings-item">
            <span>❓ Help Center</span>
            <span>→</span>
        </div>
        <div class="settings-item">
            <span>📧 Contact Us</span>
            <span>→</span>
        </div>
        <div class="settings-item">
            <span>⭐ Rate App</span>
            <span>→</span>
        </div>
    </div>
    """, unsafe_allow_html=True)
    
    # Logout button
    col1, col2, col3 = st.columns([1, 2, 1])
    with col2:
        if st.button("🚪 Logout", key="logout", use_container_width=True):
            st.session_state.authenticated = False
            st.session_state.current_page = 'landing'
            st.rerun()