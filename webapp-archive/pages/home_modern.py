import streamlit as st
from utils.logo import render_logo
from utils.session import add_points
from streamlit_extras.let_it_rain import rain

def show_home():
    # Modern home page styling
    st.markdown("""
        <style>
        @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap');
        
        /* Clean background */
        .main {
            background: #FAFAFA;
        }
        
        /* Navigation bar */
        .nav-bar {
            background: white;
            padding: 16px 24px;
            border-bottom: 1px solid #e5e5e5;
            position: sticky;
            top: 0;
            z-index: 100;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        /* Stats cards */
        .stat-card {
            background: white;
            padding: 24px;
            border-radius: 16px;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
            text-align: center;
            transition: all 0.3s ease;
        }
        
        .stat-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 16px rgba(0, 0, 0, 0.08);
        }
        
        .stat-number {
            font-size: 32px;
            font-weight: 800;
            color: #1a1a1a;
            margin: 0;
        }
        
        .stat-label {
            font-size: 14px;
            color: #666;
            margin-top: 4px;
        }
        
        /* Quick action cards */
        .action-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 32px;
            border-radius: 20px;
            color: white;
            text-align: center;
            cursor: pointer;
            transition: all 0.3s ease;
            box-shadow: 0 10px 30px rgba(102, 126, 234, 0.3);
        }
        
        .action-card:hover {
            transform: translateY(-4px);
            box-shadow: 0 15px 40px rgba(102, 126, 234, 0.4);
        }
        
        .action-icon {
            font-size: 48px;
            margin-bottom: 16px;
        }
        
        .action-title {
            font-size: 24px;
            font-weight: 700;
            margin-bottom: 8px;
        }
        
        .action-description {
            font-size: 16px;
            opacity: 0.9;
        }
        
        /* Feed section */
        .feed-card {
            background: white;
            border-radius: 16px;
            overflow: hidden;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
            margin-bottom: 20px;
            transition: all 0.3s ease;
        }
        
        .feed-card:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 20px rgba(0, 0, 0, 0.12);
        }
        
        .feed-header {
            padding: 16px;
            border-bottom: 1px solid #f0f0f0;
            display: flex;
            align-items: center;
            gap: 12px;
        }
        
        .feed-avatar {
            width: 40px;
            height: 40px;
            border-radius: 50%;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-weight: 600;
        }
        
        .feed-username {
            font-weight: 600;
            color: #1a1a1a;
        }
        
        .feed-time {
            color: #999;
            font-size: 14px;
        }
        
        .feed-content {
            padding: 16px;
        }
        
        .feed-image {
            width: 100%;
            height: 300px;
            object-fit: cover;
            background: #f0f0f0;
        }
        
        .feed-actions {
            padding: 16px;
            border-top: 1px solid #f0f0f0;
            display: flex;
            gap: 24px;
        }
        
        .feed-action {
            display: flex;
            align-items: center;
            gap: 8px;
            color: #666;
            cursor: pointer;
            transition: color 0.3s ease;
        }
        
        .feed-action:hover {
            color: #667eea;
        }
        </style>
    """, unsafe_allow_html=True)
    
    # Header with user info
    col1, col2, col3 = st.columns([1, 2, 1])
    
    with col1:
        st.markdown(render_logo("small"), unsafe_allow_html=True)
    
    with col3:
        if st.button("👤 Profile", key="profile_btn"):
            st.session_state.current_page = 'profile'
            st.rerun()
    
    # Welcome message
    st.markdown(f"### Welcome back, {st.session_state.get('username', 'Chef')}! 👋")
    
    # Stats row
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        st.markdown("""
            <div class="stat-card">
                <h2 class="stat-number">12</h2>
                <p class="stat-label">Recipes Created</p>
            </div>
        """, unsafe_allow_html=True)
    
    with col2:
        st.markdown("""
            <div class="stat-card">
                <h2 class="stat-number">$47</h2>
                <p class="stat-label">Saved This Month</p>
            </div>
        """, unsafe_allow_html=True)
    
    with col3:
        st.markdown(f"""
            <div class="stat-card">
                <h2 class="stat-number">{st.session_state.get('cooking_streak', 0)}</h2>
                <p class="stat-label">Day Streak 🔥</p>
            </div>
        """, unsafe_allow_html=True)
    
    with col4:
        st.markdown(f"""
            <div class="stat-card">
                <h2 class="stat-number">{st.session_state.get('user_points', 0)}</h2>
                <p class="stat-label">Total Points</p>
            </div>
        """, unsafe_allow_html=True)
    
    # Quick actions
    st.markdown("<br>", unsafe_allow_html=True)
    st.markdown("### Quick Actions")
    
    col1, col2 = st.columns(2)
    
    with col1:
        action_html = """
        <div class="action-card">
            <div class="action-icon">📸</div>
            <div class="action-title">Snap Your Fridge</div>
            <div class="action-description">Turn ingredients into recipes</div>
        </div>
        """
        st.markdown(action_html, unsafe_allow_html=True)
        if st.button("", key="snap_action", label_visibility="collapsed"):
            st.session_state.current_page = 'camera'
            st.rerun()
    
    with col2:
        action_html = """
        <div class="action-card" style="background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);">
            <div class="action-icon">🏆</div>
            <div class="action-title">Daily Challenge</div>
            <div class="action-description">Win points and badges</div>
        </div>
        """
        st.markdown(action_html, unsafe_allow_html=True)
        if st.button("", key="challenge_action", label_visibility="collapsed"):
            st.balloons()
            add_points(5, "Joined challenge")
    
    # Recipe feed
    st.markdown("<br>", unsafe_allow_html=True)
    st.markdown("### Community Creations 🌟")
    
    # Mock feed items
    feed_items = [
        {
            "user": "Sarah M",
            "time": "2 hours ago",
            "recipe": "Zero-Waste Veggie Stir Fry",
            "likes": 42,
            "comments": 8,
            "saved": "$12"
        },
        {
            "user": "Mike T",
            "time": "5 hours ago",
            "recipe": "Leftover Magic Pasta",
            "likes": 38,
            "comments": 5,
            "saved": "$8"
        }
    ]
    
    for item in feed_items:
        feed_html = f"""
        <div class="feed-card">
            <div class="feed-header">
                <div class="feed-avatar">{item['user'][0]}</div>
                <div>
                    <div class="feed-username">{item['user']}</div>
                    <div class="feed-time">{item['time']}</div>
                </div>
            </div>
            <div class="feed-image"></div>
            <div class="feed-content">
                <h4>{item['recipe']}</h4>
                <p>Saved {item['saved']} with this meal!</p>
            </div>
            <div class="feed-actions">
                <div class="feed-action">
                    <span>❤️</span>
                    <span>{item['likes']}</span>
                </div>
                <div class="feed-action">
                    <span>💬</span>
                    <span>{item['comments']}</span>
                </div>
                <div class="feed-action">
                    <span>📤</span>
                    <span>Share</span>
                </div>
            </div>
        </div>
        """
        st.markdown(feed_html, unsafe_allow_html=True)
    
    # Bottom navigation
    st.markdown("<br><br><br>", unsafe_allow_html=True)
    
    # Fixed bottom nav
    nav_html = """
    <div style="position: fixed; bottom: 0; left: 0; right: 0; background: white; border-top: 1px solid #e5e5e5; padding: 12px;">
        <div style="max-width: 600px; margin: 0 auto; display: flex; justify-content: space-around;">
            <div style="text-align: center; color: #667eea;">
                <div>🏠</div>
                <div style="font-size: 12px;">Home</div>
            </div>
            <div style="text-align: center; color: #999; cursor: pointer;">
                <div>📸</div>
                <div style="font-size: 12px;">Snap</div>
            </div>
            <div style="text-align: center; color: #999; cursor: pointer;">
                <div>📚</div>
                <div style="font-size: 12px;">Recipes</div>
            </div>
            <div style="text-align: center; color: #999; cursor: pointer;">
                <div>👤</div>
                <div style="font-size: 12px;">Profile</div>
            </div>
        </div>
    </div>
    """
    st.markdown(nav_html, unsafe_allow_html=True)