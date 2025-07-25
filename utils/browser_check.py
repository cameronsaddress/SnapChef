"""
Browser capability checking utilities
"""

import streamlit as st
import streamlit.components.v1 as components

def check_browser_capabilities():
    """
    Check browser capabilities and permissions for camera access
    Returns a dict with capability information
    """
    
    # JavaScript to check browser capabilities
    capability_check_script = """
    <script>
    (function() {
        const capabilities = {
            hasGetUserMedia: false,
            isSecureContext: false,
            hasCameraPermission: 'unknown',
            browserName: 'unknown',
            isMobile: false,
            hasMediaDevices: false
        };
        
        // Check for getUserMedia support
        capabilities.hasGetUserMedia = !!(navigator.mediaDevices && navigator.mediaDevices.getUserMedia);
        
        // Check if in secure context (HTTPS)
        capabilities.isSecureContext = window.isSecureContext;
        
        // Detect browser
        const userAgent = navigator.userAgent;
        if (userAgent.indexOf("Chrome") > -1) {
            capabilities.browserName = "Chrome";
        } else if (userAgent.indexOf("Safari") > -1) {
            capabilities.browserName = "Safari";
        } else if (userAgent.indexOf("Firefox") > -1) {
            capabilities.browserName = "Firefox";
        } else if (userAgent.indexOf("Edge") > -1) {
            capabilities.browserName = "Edge";
        }
        
        // Check if mobile
        capabilities.isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(userAgent);
        
        // Check for media devices API
        capabilities.hasMediaDevices = 'mediaDevices' in navigator;
        
        // Check camera permission (async)
        if (navigator.permissions && navigator.permissions.query) {
            navigator.permissions.query({ name: 'camera' })
                .then(permissionStatus => {
                    capabilities.hasCameraPermission = permissionStatus.state;
                    // Send data to Streamlit
                    window.parent.postMessage({
                        type: 'streamlit:setComponentValue',
                        key: 'browser_capabilities',
                        value: capabilities
                    }, '*');
                })
                .catch(() => {
                    // Permissions API not supported
                    capabilities.hasCameraPermission = 'not_supported';
                    window.parent.postMessage({
                        type: 'streamlit:setComponentValue',
                        key: 'browser_capabilities',
                        value: capabilities
                    }, '*');
                });
        } else {
            // Send data without permission info
            window.parent.postMessage({
                type: 'streamlit:setComponentValue',
                key: 'browser_capabilities',
                value: capabilities
            }, '*');
        }
    })();
    </script>
    """
    
    # Inject the script
    components.html(capability_check_script, height=0)
    
    # Return stored capabilities from session state
    return st.session_state.get('browser_capabilities', {
        'hasGetUserMedia': True,  # Assume true by default
        'isSecureContext': True,
        'hasCameraPermission': 'unknown',
        'browserName': 'unknown',
        'isMobile': False,
        'hasMediaDevices': True
    })

def get_camera_troubleshooting_guide(capabilities):
    """
    Get troubleshooting guide based on browser capabilities
    """
    guide = []
    
    if not capabilities.get('isSecureContext', True):
        guide.append({
            'issue': 'Not using HTTPS',
            'solution': 'Camera access requires a secure connection. Access the site using https:// instead of http://'
        })
    
    if not capabilities.get('hasGetUserMedia', True):
        guide.append({
            'issue': 'Browser doesn\'t support camera access',
            'solution': 'Please use a modern browser like Chrome, Firefox, Safari, or Edge'
        })
    
    if capabilities.get('hasCameraPermission') == 'denied':
        guide.append({
            'issue': 'Camera permission denied',
            'solution': 'Click the camera icon in your browser\'s address bar and allow camera access'
        })
    
    browser = capabilities.get('browserName', 'unknown')
    if browser == 'Safari' and capabilities.get('isMobile'):
        guide.append({
            'issue': 'iOS Safari camera limitations',
            'solution': 'On iOS, make sure Safari has camera permission in Settings > Safari > Camera'
        })
    
    return guide

def show_browser_compatibility_notice():
    """
    Show a notice about browser compatibility
    """
    st.info("""
    📱 **Camera Compatibility**
    
    **Supported Browsers:**
    - ✅ Chrome (Desktop & Mobile)
    - ✅ Safari (Desktop & iOS)
    - ✅ Firefox (Desktop & Mobile)
    - ✅ Edge (Desktop & Mobile)
    
    **Requirements:**
    - 🔒 HTTPS connection (or localhost)
    - 📸 Camera permission granted
    - 🌐 Modern browser version
    """)

def show_permission_helper(browser_name="your browser"):
    """
    Show browser-specific permission instructions
    """
    
    instructions = {
        "Chrome": """
        **Chrome - Camera Permission:**
        1. Click the camera icon in the address bar
        2. Select "Allow" for camera access
        3. Refresh the page if needed
        """,
        "Safari": """
        **Safari - Camera Permission:**
        1. Go to Safari > Preferences > Websites > Camera
        2. Find this website and set to "Allow"
        3. On iOS: Settings > Safari > Camera > Allow
        """,
        "Firefox": """
        **Firefox - Camera Permission:**
        1. Click the camera icon in the address bar
        2. Select "Allow" for camera access
        3. Or go to Settings > Privacy & Security > Permissions > Camera
        """,
        "Edge": """
        **Edge - Camera Permission:**
        1. Click the lock icon in the address bar
        2. Find "Camera" and set to "Allow"
        3. Refresh the page
        """
    }
    
    # Get browser-specific instructions
    specific_instructions = instructions.get(browser_name, """
        **Camera Permission:**
        1. Look for a camera icon in your browser's address bar
        2. Click it and select "Allow" for camera access
        3. If you don't see it, check your browser's settings for camera permissions
    """)
    
    st.markdown(specific_instructions)