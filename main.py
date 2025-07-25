import streamlit as st
import os
from dotenv import load_dotenv
from utils.auth import init_auth, check_auth
from utils.database import init_db
from utils.session import init_session_state

# Load environment variables
load_dotenv()

# Page configuration
st.set_page_config(
    page_title="SnapChef - Turn Your Fridge into Meals",
    page_icon="🍳",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Initialize database
init_db()

# Initialize session state
init_session_state()

# Initialize authentication
authenticator = init_auth()

# Main navigation
def main():
    # Redirect to the new modern app
    st.markdown("""
        <div style="display: flex; align-items: center; justify-content: center; height: 100vh;">
            <div style="text-align: center;">
                <h1>SnapChef has moved!</h1>
                <p>Please access the app using app.py instead of main.py</p>
                <p style="margin-top: 20px; padding: 10px 20px; background: #f0f0f0; border-radius: 8px; font-family: monospace;">
                    streamlit run app.py
                </p>
            </div>
        </div>
    """, unsafe_allow_html=True)

if __name__ == "__main__":
    main()