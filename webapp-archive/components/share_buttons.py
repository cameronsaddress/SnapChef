"""
Social media share buttons component
"""
import streamlit as st
import urllib.parse

def render_share_buttons(recipe_name: str, recipe_idx: int):
    """Render styled share buttons for TikTok and Instagram"""
    
    # Share text
    share_text = f"I just made {recipe_name} using SnapChef ✨! Turn your fridge into amazing meals with AI 🍳"
    share_url = "https://snapchef.app"  # Update with actual URL
    
    # URL encode the text
    encoded_text = urllib.parse.quote(share_text)
    encoded_url = urllib.parse.quote(share_url)
    
    # TikTok share URL (opens TikTok web with pre-filled caption)
    tiktok_url = f"https://www.tiktok.com/upload?caption={encoded_text}%20{encoded_url}"
    
    # Instagram doesn't have a direct share URL, so we'll use a copy-to-clipboard approach
    instagram_text = f"{share_text}\n\n📸 Share your creation on Instagram Stories and tag @snapchef_app\n\n#SnapChef #AIRecipes #FoodHack #RecipeOfTheDay"
    
    # Styling
    st.markdown(f"""
        <style>
        /* TikTok button styling */
        .tiktok-button-{recipe_idx} {{
            background: #000000 !important;
            color: white !important;
            border: none !important;
            padding: 0.75rem 1.5rem !important;
            border-radius: 8px !important;
            font-weight: 600 !important;
            font-size: 0.9rem !important;
            display: flex !important;
            align-items: center !important;
            justify-content: center !important;
            gap: 0.5rem !important;
            width: 100% !important;
            cursor: pointer !important;
            transition: all 0.2s ease !important;
            text-decoration: none !important;
            margin-bottom: 0.5rem !important;
        }}
        
        .tiktok-button-{recipe_idx}:hover {{
            background: #FF0050 !important;
            transform: translateY(-2px) !important;
            box-shadow: 0 4px 12px rgba(255, 0, 80, 0.3) !important;
        }}
        
        /* Instagram button styling */
        .instagram-button-{recipe_idx} {{
            background: linear-gradient(45deg, #405DE6, #5851DB, #833AB4, #C13584, #E1306C, #FD1D1D) !important;
            color: white !important;
            border: none !important;
            padding: 0.75rem 1.5rem !important;
            border-radius: 8px !important;
            font-weight: 600 !important;
            font-size: 0.9rem !important;
            display: flex !important;
            align-items: center !important;
            justify-content: center !important;
            gap: 0.5rem !important;
            width: 100% !important;
            cursor: pointer !important;
            transition: all 0.2s ease !important;
            text-decoration: none !important;
        }}
        
        .instagram-button-{recipe_idx}:hover {{
            transform: translateY(-2px) !important;
            box-shadow: 0 4px 12px rgba(131, 58, 180, 0.4) !important;
            opacity: 0.9 !important;
        }}
        
        /* Share container */
        .share-container-{recipe_idx} {{
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            padding: 1.5rem;
            border-radius: 12px;
            margin-top: 1rem;
        }}
        
        .share-title {{
            color: white;
            font-size: 1.1rem;
            font-weight: 600;
            margin-bottom: 1rem;
            text-align: center;
        }}
        
        .share-subtitle {{
            color: rgba(255, 255, 255, 0.8);
            font-size: 0.9rem;
            text-align: center;
            margin-bottom: 1rem;
        }}
        
        /* Icon styling */
        .social-icon {{
            width: 20px;
            height: 20px;
            vertical-align: middle;
        }}
        </style>
    """, unsafe_allow_html=True)
    
    # Share container
    st.markdown(f'<div class="share-container-{recipe_idx}">', unsafe_allow_html=True)
    st.markdown('<div class="share-title">🎉 Share Your Creation!</div>', unsafe_allow_html=True)
    st.markdown('<div class="share-subtitle">Get 5 credits for each share!</div>', unsafe_allow_html=True)
    
    col1, col2 = st.columns(2)
    
    with col1:
        # TikTok share button
        if st.button("", key=f"tiktok_{recipe_idx}", use_container_width=True):
            # Track share event
            if 'shares' not in st.session_state:
                st.session_state.shares = []
            st.session_state.shares.append({'platform': 'tiktok', 'recipe': recipe_name})
            
            # Add credits
            if 'credits' not in st.session_state:
                st.session_state.credits = 0
            st.session_state.credits += 5
            
            # Open TikTok
            st.markdown(f'<meta http-equiv="refresh" content="0; url={tiktok_url}">', unsafe_allow_html=True)
            st.success("🎉 +5 credits! Opening TikTok...")
        
        # Custom button label with icon
        st.markdown(f"""
            <a href="{tiktok_url}" target="_blank" class="tiktok-button-{recipe_idx}">
                <svg class="social-icon" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M19.59 6.69a4.83 4.83 0 0 1-3.77-4.25V2h-3.45v13.67a2.89 2.89 0 0 1-5.2 1.74 2.89 2.89 0 0 1 2.31-4.64 2.93 2.93 0 0 1 .88.13V9.4a6.84 6.84 0 0 0-1-.05A6.33 6.33 0 0 0 5 20.1a6.34 6.34 0 0 0 10.86-4.43v-7a8.16 8.16 0 0 0 4.77 1.52v-3.4a4.85 4.85 0 0 1-1-.1z"/>
                </svg>
                Share on TikTok
            </a>
        """, unsafe_allow_html=True)
    
    with col2:
        # Instagram share button (copy to clipboard)
        if st.button("", key=f"ig_{recipe_idx}", use_container_width=True):
            # Track share event
            if 'shares' not in st.session_state:
                st.session_state.shares = []
            st.session_state.shares.append({'platform': 'instagram', 'recipe': recipe_name})
            
            # Add credits
            if 'credits' not in st.session_state:
                st.session_state.credits = 0
            st.session_state.credits += 5
            
            # Copy to clipboard using JavaScript
            st.markdown(f"""
                <script>
                navigator.clipboard.writeText(`{instagram_text}`).then(function() {{
                    console.log('Copied to clipboard');
                }});
                </script>
            """, unsafe_allow_html=True)
            
            st.success("🎉 +5 credits! Caption copied to clipboard! Open Instagram and paste.")
        
        # Custom button label with icon
        st.markdown(f"""
            <button class="instagram-button-{recipe_idx}" onclick="navigator.clipboard.writeText(`{instagram_text}`)">
                <svg class="social-icon" viewBox="0 0 24 24" fill="currentColor">
                    <path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073zM5.838 12a6.162 6.162 0 1 1 12.324 0 6.162 6.162 0 0 1-12.324 0zM12 16a4 4 0 1 1 0-8 4 4 0 0 1 0 8zm4.965-10.405a1.44 1.44 0 1 1 2.881.001 1.44 1.44 0 0 1-2.881-.001z"/>
                </svg>
                Share on Instagram
            </button>
        """, unsafe_allow_html=True)
    
    st.markdown('</div>', unsafe_allow_html=True)
    
    # Show credits earned
    if 'credits' in st.session_state and st.session_state.credits > 0:
        st.markdown(f"""
            <div style="text-align: center; margin-top: 1rem; color: white;">
                <span style="font-size: 1.2rem;">💰 Total Credits: {st.session_state.credits}</span>
            </div>
        """, unsafe_allow_html=True)