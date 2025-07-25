import streamlit as st
from urllib.parse import quote
from typing import Dict, Optional
import json

def generate_share_url(platform: str, content: Dict) -> str:
    """Generate platform-specific share URLs"""
    
    base_urls = {
        'tiktok': 'https://www.tiktok.com/upload',
        'instagram': 'https://www.instagram.com/',
        'twitter': 'https://twitter.com/intent/tweet',
        'facebook': 'https://www.facebook.com/sharer/sharer.php',
        'whatsapp': 'https://api.whatsapp.com/send',
        'snapchat': 'https://www.snapchat.com/scan',
        'pinterest': 'https://pinterest.com/pin/create/button/'
    }
    
    text = content.get('text', '')
    url = content.get('url', 'https://snapchef.app')
    hashtags = content.get('hashtags', ['SnapChefChallenge', 'WhatsInYourFridge'])
    
    if platform == 'twitter':
        hashtag_str = ' '.join([f'#{tag}' for tag in hashtags])
        full_text = f"{text} {hashtag_str} {url}"
        return f"{base_urls[platform]}?text={quote(full_text)}"
    
    elif platform == 'facebook':
        return f"{base_urls[platform]}?u={quote(url)}&quote={quote(text)}"
    
    elif platform == 'whatsapp':
        full_text = f"{text} {url}"
        return f"{base_urls[platform]}?text={quote(full_text)}"
    
    elif platform == 'tiktok':
        # TikTok doesn't have direct URL sharing, return upload page
        return base_urls[platform]
    
    elif platform == 'instagram':
        # Instagram doesn't support direct sharing via URL
        return base_urls[platform]
    
    elif platform == 'pinterest':
        description = quote(text)
        media = content.get('image_url', '')
        return f"{base_urls[platform]}?url={quote(url)}&description={description}&media={quote(media)}"
    
    else:
        return base_urls.get(platform, '#')

def create_share_content(recipe: Dict, share_type: str = 'recipe') -> Dict:
    """Create share content based on type"""
    
    if share_type == 'recipe':
        text = recipe.get('share_caption', f"Just made {recipe.get('name', 'this amazing dish')} with SnapChef! 🍳✨")
        hashtags = ['SnapChefChallenge', 'WhatsInYourFridge', 'ZeroWaste', 'HomeCooking']
        
    elif share_type == 'challenge':
        text = f"I just completed the {recipe.get('name', 'SnapChef challenge')}! Can you beat my score? 🏆"
        hashtags = ['SnapChefChallenge', 'CookingChallenge', 'FoodChallenge']
        
    elif share_type == 'fridge_reveal':
        text = "Can you guess what meal I'm making with these ingredients? 🤔 #FridgeReveal"
        hashtags = ['FridgeReveal', 'SnapChef', 'GuessTheMeal', 'WhatsInYourFridge']
        
    elif share_type == 'streak':
        streak_days = recipe.get('streak_days', 7)
        text = f"I'm on a {streak_days}-day cooking streak with SnapChef! 🔥 Join me!"
        hashtags = ['CookingStreak', 'SnapChef', 'DailyChef', 'HealthyHabits']
        
    else:  # referral
        referral_code = recipe.get('referral_code', 'SNAP123')
        text = f"Turn your fridge into delicious meals with SnapChef! Use my code {referral_code} for 30 bonus points 🎁"
        hashtags = ['SnapChef', 'CookingApp', 'SaveFood', 'FreePoints']
    
    return {
        'text': text,
        'hashtags': hashtags,
        'url': 'https://snapchef.app',
        'image_url': recipe.get('image_url', '')
    }

def show_share_buttons(content: Dict, platforms: list = None, key_prefix: str = ""):
    """Display share buttons for multiple platforms"""
    
    if platforms is None:
        platforms = ['tiktok', 'instagram', 'twitter', 'facebook']
    
    cols = st.columns(len(platforms))
    
    platform_names = {
        'tiktok': '📱 TikTok',
        'instagram': '📷 Instagram',
        'twitter': '🐦 Twitter',
        'facebook': '📘 Facebook',
        'whatsapp': '💬 WhatsApp',
        'snapchat': '👻 Snapchat',
        'pinterest': '📌 Pinterest'
    }
    
    for idx, platform in enumerate(platforms):
        with cols[idx]:
            share_url = generate_share_url(platform, content)
            button_label = platform_names.get(platform, platform.title())
            
            if st.button(button_label, key=f"{key_prefix}share_{platform}", use_container_width=True):
                # Track sharing
                st.session_state['shares'] = st.session_state.get('shares', 0) + 1
                
                # Award points
                from utils.session import add_points
                add_points(10, f"Shared on {platform}")
                
                # Show success message
                st.success(f"Opening {platform}... +10 points!")
                
                # For web platforms, could use st.markdown with link
                if platform in ['twitter', 'facebook', 'whatsapp']:
                    st.markdown(f'<meta http-equiv="refresh" content="0; url={share_url}">', unsafe_allow_html=True)

def create_video_share_content(recipe: Dict) -> Dict:
    """Create content specifically for video sharing"""
    
    script_intro = f"POV: You turned {len(recipe.get('ingredients', []))} random fridge items into {recipe.get('name', 'an amazing meal')}"
    
    script_parts = [
        "🎬 Hook (0-3s): Show the final dish with dramatic music",
        f"📸 Reveal (3-5s): {script_intro}",
        "🥘 Process (5-20s): Quick montage of cooking steps",
        "✨ Transform (20-25s): Before/after of fridge items → final meal",
        "📱 CTA (25-30s): 'Download SnapChef - link in bio!'"
    ]
    
    return {
        'script': '\n'.join(script_parts),
        'duration': '30 seconds',
        'format': 'Vertical (9:16)',
        'music_suggestion': 'Trending upbeat cooking sound',
        'hashtags': ['SnapChefChallenge', 'CookTok', 'FoodWaste', 'QuickRecipe', 'FridgeToTable'],
        'caption': recipe.get('share_caption', '')
    }

def track_share_analytics(platform: str, content_type: str, recipe_id: Optional[int] = None):
    """Track sharing analytics"""
    
    # In production, this would save to database
    if 'share_analytics' not in st.session_state:
        st.session_state.share_analytics = []
    
    analytics_entry = {
        'platform': platform,
        'content_type': content_type,
        'recipe_id': recipe_id,
        'timestamp': st.session_state.get('current_time', 'now'),
        'user_id': st.session_state.get('user_id')
    }
    
    st.session_state.share_analytics.append(analytics_entry)

def get_viral_tips(platform: str) -> list:
    """Get platform-specific tips for going viral"""
    
    tips = {
        'tiktok': [
            "🎵 Use trending audio",
            "⏱️ Keep it under 30 seconds",
            "🎬 Start with the final result",
            "📱 Film in vertical format",
            "💬 Ask a question to boost comments"
        ],
        'instagram': [
            "📸 Use high-quality photos",
            "🎨 Consistent aesthetic",
            "📝 Write engaging captions",
            "🏷️ Use 10-15 relevant hashtags",
            "📍 Add location tags"
        ],
        'twitter': [
            "🧵 Create a thread for recipes",
            "📊 Post at peak times (6-9 PM)",
            "🖼️ Always include images",
            "💬 Engage with replies",
            "🔄 Retweet with updates"
        ],
        'facebook': [
            "👥 Share to relevant groups",
            "📝 Tell a story",
            "🎥 Use Facebook Live",
            "😊 Include emojis",
            "💬 Respond to comments quickly"
        ]
    }
    
    return tips.get(platform, ["📱 Be authentic", "🎯 Know your audience", "📊 Post consistently"])

def generate_community_post(post_type: str, data: Dict) -> Dict:
    """Generate community post content"""
    
    if post_type == 'fridge_reveal':
        return {
            'title': "🎭 Mystery Fridge Challenge",
            'content': "Can you guess what meals I can make with these ingredients?",
            'image': data.get('image_url'),
            'poll_options': ["Pasta dish", "Stir-fry", "Soup", "Salad"],
            'rewards': {'correct_guess': 5, 'participation': 2}
        }
    
    elif post_type == 'recipe_remix':
        return {
            'title': f"🔄 Remix Challenge: {data.get('original_recipe')}",
            'content': "Show us your version of this recipe!",
            'original_recipe_id': data.get('recipe_id'),
            'rewards': {'best_remix': 50, 'participation': 10}
        }
    
    elif post_type == 'vote_battle':
        return {
            'title': "⚔️ Recipe Battle",
            'content': "Which meal looks more delicious?",
            'option_a': data.get('recipe_a'),
            'option_b': data.get('recipe_b'),
            'voting_ends': "24 hours",
            'rewards': {'correct_vote': 3}
        }
    
    return {}

def calculate_virality_score(shares: int, views: int, engagement_rate: float) -> int:
    """Calculate virality score for content"""
    
    # Weighted scoring system
    share_weight = 0.4
    view_weight = 0.3
    engagement_weight = 0.3
    
    # Normalize values (basic example)
    normalized_shares = min(shares / 100, 1) * 100
    normalized_views = min(views / 1000, 1) * 100
    normalized_engagement = engagement_rate * 10
    
    score = (
        normalized_shares * share_weight +
        normalized_views * view_weight +
        normalized_engagement * engagement_weight
    )
    
    return int(score)