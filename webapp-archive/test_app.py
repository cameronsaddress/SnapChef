#!/usr/bin/env python3
"""Test script to verify SnapChef app is running"""

import requests
import time

def test_app():
    """Test if the app is running"""
    url = "http://localhost:8501"
    
    print("🧪 Testing SnapChef app...")
    
    try:
        # Give the app time to start
        time.sleep(2)
        
        # Test if the app is accessible
        response = requests.get(url, timeout=5)
        
        if response.status_code == 200:
            print("✅ App is running successfully!")
            print(f"📍 Access it at: {url}")
            print("\n📝 Login credentials:")
            print("   Username: demo_user")
            print("   Password: demo123")
            print("\n🚀 Features available:")
            print("   - Upload fridge photos")
            print("   - Generate AI recipes") 
            print("   - Share on social media")
            print("   - Complete challenges")
            print("   - Track points & streaks")
            return True
        else:
            print(f"❌ App returned status code: {response.status_code}")
            return False
            
    except requests.ConnectionError:
        print("❌ Could not connect to the app")
        print("💡 Make sure the app is running with: streamlit run main.py")
        return False
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return False

if __name__ == "__main__":
    test_app()