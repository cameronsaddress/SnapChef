import streamlit as st

def render_logo(size="large", gradient=True):
    """Render the SnapChef logo as pure CSS/HTML"""
    
    sizes = {
        "small": {"font": "24px", "icon": "20px"},
        "medium": {"font": "36px", "icon": "32px"},
        "large": {"font": "48px", "icon": "44px"},
        "hero": {"font": "64px", "icon": "60px"}
    }
    
    font_size = sizes.get(size, sizes["large"])["font"]
    icon_size = sizes.get(size, sizes["large"])["icon"]
    
    if gradient:
        logo_html = f"""
        <div style="text-align: center; margin: 20px 0;">
            <div style="display: inline-flex; align-items: center; gap: 12px;">
                <div style="
                    width: {icon_size};
                    height: {icon_size};
                    background: linear-gradient(135deg, #25F4EE 0%, #FE2C55 100%);
                    border-radius: 12px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    font-size: calc({icon_size} * 0.6);
                    box-shadow: 0 8px 32px rgba(254, 44, 85, 0.3);
                ">
                    📸
                </div>
                <span style="
                    font-size: {font_size};
                    font-weight: 800;
                    background: linear-gradient(135deg, #25F4EE 0%, #FE2C55 100%);
                    -webkit-background-clip: text;
                    -webkit-text-fill-color: transparent;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
                    letter-spacing: -0.02em;
                ">SnapChef</span>
            </div>
        </div>
        """
    else:
        logo_html = f"""
        <div style="text-align: center; margin: 20px 0;">
            <div style="display: inline-flex; align-items: center; gap: 12px;">
                <div style="
                    width: {icon_size};
                    height: {icon_size};
                    background: #000;
                    border-radius: 12px;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    font-size: calc({icon_size} * 0.6);
                ">
                    📸
                </div>
                <span style="
                    font-size: {font_size};
                    font-weight: 800;
                    color: #000;
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
                    letter-spacing: -0.02em;
                ">SnapChef</span>
            </div>
        </div>
        """
    
    return logo_html

def render_icon(emoji="📸", size=24, bg_color=None):
    """Render a minimalist icon with optional background"""
    
    if bg_color:
        icon_html = f"""
        <div style="
            width: {size}px;
            height: {size}px;
            background: {bg_color};
            border-radius: 8px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            font-size: {size * 0.6}px;
        ">{emoji}</div>
        """
    else:
        icon_html = f"""
        <span style="font-size: {size}px;">{emoji}</span>
        """
    
    return icon_html