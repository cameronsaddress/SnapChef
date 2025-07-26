"""
Device fingerprinting for tracking free uses without authentication
"""
import hashlib
import json
from typing import Dict, Optional
import streamlit as st
from datetime import datetime, timedelta

def get_device_fingerprint() -> str:
    """
    Generate a device fingerprint based on various browser/device characteristics.
    Uses Streamlit's session info and JavaScript for additional entropy.
    """
    # Collect available data points
    fingerprint_data = {
        # Session info
        "session_id": st.session_state.get("_session_id", ""),
        
        # Browser info (will be populated by JavaScript)
        "user_agent": st.session_state.get("user_agent", ""),
        "screen_resolution": st.session_state.get("screen_resolution", ""),
        "timezone": st.session_state.get("timezone", ""),
        "language": st.session_state.get("language", ""),
        "platform": st.session_state.get("platform", ""),
        "canvas_fingerprint": st.session_state.get("canvas_fingerprint", ""),
        
        # Additional entropy
        "color_depth": st.session_state.get("color_depth", ""),
        "pixel_ratio": st.session_state.get("pixel_ratio", ""),
        "hardware_concurrency": st.session_state.get("hardware_concurrency", ""),
        "available_fonts": st.session_state.get("available_fonts", ""),
    }
    
    # Create a stable hash
    fingerprint_string = json.dumps(fingerprint_data, sort_keys=True)
    device_id = hashlib.sha256(fingerprint_string.encode()).hexdigest()
    
    return device_id

def inject_fingerprint_collector():
    """Inject JavaScript to collect device fingerprint data"""
    
    js_code = """
    <script>
    // Canvas fingerprinting
    function getCanvasFingerprint() {
        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');
        canvas.width = 200;
        canvas.height = 50;
        
        // Draw unique content
        ctx.textBaseline = 'top';
        ctx.font = '14px "Arial"';
        ctx.textBaseline = 'alphabetic';
        ctx.fillStyle = '#f60';
        ctx.fillRect(125, 1, 62, 20);
        ctx.fillStyle = '#069';
        ctx.fillText('SnapChef fingerprint 🍳', 2, 15);
        ctx.fillStyle = 'rgba(102, 204, 0, 0.7)';
        ctx.fillText('SnapChef fingerprint 🍳', 4, 17);
        
        return canvas.toDataURL();
    }
    
    // Font detection
    function getAvailableFonts() {
        const baseFonts = ['monospace', 'sans-serif', 'serif'];
        const testFonts = ['Arial', 'Verdana', 'Times New Roman', 'Courier New', 'Georgia'];
        const detected = [];
        
        const span = document.createElement('span');
        span.style.position = 'absolute';
        span.style.left = '-9999px';
        span.style.fontSize = '72px';
        span.innerHTML = 'mmmmmmmmmmlli';
        document.body.appendChild(span);
        
        const defaultWidths = {};
        baseFonts.forEach(baseFont => {
            span.style.fontFamily = baseFont;
            defaultWidths[baseFont] = span.offsetWidth;
        });
        
        testFonts.forEach(font => {
            let detected = false;
            baseFonts.forEach(baseFont => {
                span.style.fontFamily = `'${font}', ${baseFont}`;
                if (span.offsetWidth !== defaultWidths[baseFont]) {
                    detected = true;
                }
            });
            if (detected) {
                detected.push(font);
            }
        });
        
        document.body.removeChild(span);
        return detected.join(',');
    }
    
    // Collect fingerprint data
    function collectFingerprint() {
        const fingerprint = {
            user_agent: navigator.userAgent,
            screen_resolution: screen.width + 'x' + screen.height,
            timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
            language: navigator.language,
            platform: navigator.platform,
            canvas_fingerprint: getCanvasFingerprint().substring(0, 50), // Truncate for performance
            color_depth: screen.colorDepth,
            pixel_ratio: window.devicePixelRatio || 1,
            hardware_concurrency: navigator.hardwareConcurrency || 0,
            available_fonts: getAvailableFonts()
        };
        
        // Send to Streamlit
        window.parent.postMessage({
            type: 'streamlit:setComponentValue',
            value: fingerprint
        }, '*');
        
        // Also try direct assignment if available
        if (window.Streamlit) {
            Object.keys(fingerprint).forEach(key => {
                window.Streamlit.setComponentValue(key, fingerprint[key]);
            });
        }
    }
    
    // Run on load
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', collectFingerprint);
    } else {
        collectFingerprint();
    }
    </script>
    """
    
    return js_code

def check_free_uses(device_id: str) -> Dict[str, any]:
    """
    Check remaining free uses for a device.
    Returns dict with uses_remaining and other metadata.
    """
    # Initialize device tracking in session state
    if 'device_tracking' not in st.session_state:
        st.session_state.device_tracking = {}
    
    # Get or create device record
    if device_id not in st.session_state.device_tracking:
        st.session_state.device_tracking[device_id] = {
            'first_seen': datetime.now().isoformat(),
            'last_seen': datetime.now().isoformat(),
            'uses_remaining': 3,  # Default free uses
            'total_uses': 0,
            'is_authenticated': False,
            'user_id': None
        }
    
    device_data = st.session_state.device_tracking[device_id]
    device_data['last_seen'] = datetime.now().isoformat()
    
    return device_data

def decrement_free_use(device_id: str) -> bool:
    """
    Decrement free use counter for device.
    Returns True if use was allowed, False if no uses remaining.
    """
    device_data = check_free_uses(device_id)
    
    if device_data['uses_remaining'] > 0:
        device_data['uses_remaining'] -= 1
        device_data['total_uses'] += 1
        st.session_state.device_tracking[device_id] = device_data
        return True
    
    return False

def link_device_to_user(device_id: str, user_id: str):
    """Link a device to an authenticated user"""
    if device_id in st.session_state.device_tracking:
        st.session_state.device_tracking[device_id]['is_authenticated'] = True
        st.session_state.device_tracking[device_id]['user_id'] = user_id
        # Reset uses for authenticated users (they have subscription)
        st.session_state.device_tracking[device_id]['uses_remaining'] = -1  # Unlimited