#!/usr/bin/env python3
"""
SnapChef Page Testing Script
Tests all pages for rendering and functionality issues
"""

import time
import sys
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException, NoSuchElementException
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
import subprocess
import os

class SnapChefTester:
    def __init__(self, headless=True):
        """Initialize the tester with Chrome webdriver"""
        self.base_url = "http://localhost:8501"
        self.issues = []
        
        # Setup Chrome options
        chrome_options = Options()
        if headless:
            chrome_options.add_argument("--headless")
        chrome_options.add_argument("--no-sandbox")
        chrome_options.add_argument("--disable-dev-shm-usage")
        chrome_options.add_argument("--window-size=1920,1080")
        
        try:
            self.driver = webdriver.Chrome(options=chrome_options)
            self.wait = WebDriverWait(self.driver, 10)
        except Exception as e:
            print(f"Error initializing Chrome driver: {e}")
            print("Please ensure Chrome and ChromeDriver are installed")
            sys.exit(1)
    
    def log_issue(self, page, issue_type, description):
        """Log an issue found on a page"""
        issue = {
            "page": page,
            "type": issue_type,
            "description": description
        }
        self.issues.append(issue)
        print(f"❌ [{page}] {issue_type}: {description}")
    
    def log_success(self, page, description):
        """Log a successful test"""
        print(f"✅ [{page}] {description}")
    
    def check_for_errors(self, page_name):
        """Check for common errors on the page"""
        # Check for JavaScript errors
        logs = self.driver.get_log('browser')
        for log in logs:
            if log['level'] == 'SEVERE':
                self.log_issue(page_name, "JavaScript Error", log['message'])
        
        # Check for Streamlit errors
        try:
            error_elements = self.driver.find_elements(By.CLASS_NAME, "stAlert")
            for error in error_elements:
                self.log_issue(page_name, "Streamlit Error", error.text)
        except:
            pass
        
        # Check for raw HTML being displayed
        page_source = self.driver.page_source
        if "&lt;" in page_source and "&gt;" in page_source:
            # Look for specific patterns that indicate HTML is being shown as text
            if "&lt;div" in page_source or "&lt;style" in page_source:
                self.log_issue(page_name, "HTML Rendering", "Raw HTML tags visible on page")
    
    def test_landing_page(self):
        """Test the landing page"""
        print("\n🧪 Testing Landing Page...")
        self.driver.get(self.base_url)
        time.sleep(3)  # Wait for Streamlit to load
        
        try:
            # Check if the hero title is present
            self.wait.until(EC.presence_of_element_located((By.XPATH, "//*[contains(text(), 'Turn Your Fridge')]"))
            self.log_success("Landing", "Hero title rendered correctly")
        except TimeoutException:
            self.log_issue("Landing", "Missing Content", "Hero title not found")
        
        # Check for SnapChef button
        try:
            snap_button = self.driver.find_element(By.XPATH, "//button[contains(text(), 'SnapChef')]")
            self.log_success("Landing", "SnapChef button found")
            
            # Test button click
            snap_button.click()
            time.sleep(2)
            
            # Check if we navigated to camera page
            if "Snap your fridge" in self.driver.page_source:
                self.log_success("Landing", "Navigation to camera page works")
                self.driver.get(self.base_url)  # Go back
                time.sleep(2)
            else:
                self.log_issue("Landing", "Navigation", "SnapChef button doesn't navigate to camera")
        except NoSuchElementException:
            self.log_issue("Landing", "Missing Element", "SnapChef button not found")
        
        # Check for features section
        try:
            features = self.driver.find_elements(By.CLASS_NAME, "feature-card")
            if len(features) >= 3:
                self.log_success("Landing", f"Features section has {len(features)} cards")
            else:
                self.log_issue("Landing", "Missing Content", f"Expected 3 feature cards, found {len(features)}")
        except:
            self.log_issue("Landing", "Missing Content", "Features section not found")
        
        self.check_for_errors("Landing")
    
    def test_auth_page(self):
        """Test the authentication page"""
        print("\n🧪 Testing Auth Page...")
        
        # Navigate to auth page by clicking sign in
        try:
            # First check if we need to use up free uses
            self.driver.get(self.base_url)
            time.sleep(2)
            
            # Set free uses to 0 to trigger auth redirect
            self.driver.execute_script("window.sessionStorage.setItem('free_uses', '0');")
            
            snap_button = self.driver.find_element(By.XPATH, "//button[contains(text(), 'SnapChef')]")
            snap_button.click()
            time.sleep(3)
            
            # Check if we're on auth page
            if "Sign In" in self.driver.page_source or "Welcome Back" in self.driver.page_source:
                self.log_success("Auth", "Redirected to auth page when free uses exhausted")
            else:
                # Try direct navigation
                self.driver.get(f"{self.base_url}/?page=auth")
                time.sleep(2)
        except Exception as e:
            self.log_issue("Auth", "Navigation", f"Could not navigate to auth page: {str(e)}")
            return
        
        # Check for tabs
        try:
            tabs = self.driver.find_elements(By.XPATH, "//button[@role='tab']")
            if len(tabs) >= 2:
                self.log_success("Auth", "Sign In and Sign Up tabs present")
                
                # Test Sign Up tab
                tabs[1].click()
                time.sleep(1)
                if "Join SnapChef" in self.driver.page_source:
                    self.log_success("Auth", "Sign Up tab works")
            else:
                self.log_issue("Auth", "Missing Element", "Auth tabs not found")
        except:
            self.log_issue("Auth", "Missing Element", "Could not find auth tabs")
        
        # Check for form fields
        try:
            email_input = self.driver.find_element(By.XPATH, "//input[@type='text' or @type='email']")
            password_input = self.driver.find_element(By.XPATH, "//input[@type='password']")
            self.log_success("Auth", "Email and password fields present")
        except:
            self.log_issue("Auth", "Missing Element", "Form fields not found")
        
        # Check for social login buttons
        if "Continue with Apple" in self.driver.page_source:
            self.log_success("Auth", "Social login buttons rendered")
        else:
            self.log_issue("Auth", "Missing Element", "Social login buttons not found")
        
        self.check_for_errors("Auth")
    
    def test_camera_page(self):
        """Test the camera page"""
        print("\n🧪 Testing Camera Page...")
        
        # Navigate to camera page
        self.driver.get(self.base_url)
        time.sleep(2)
        
        try:
            snap_button = self.driver.find_element(By.XPATH, "//button[contains(text(), 'SnapChef')]")
            snap_button.click()
            time.sleep(3)
            
            # Check for camera UI elements
            if "Snap your fridge" in self.driver.page_source:
                self.log_success("Camera", "Camera page loaded with correct title")
            else:
                self.log_issue("Camera", "Missing Content", "Camera page title not found")
            
            # Check for tabs
            tabs = self.driver.find_elements(By.XPATH, "//button[@role='tab']")
            if any("Camera" in tab.text for tab in tabs) and any("Upload" in tab.text for tab in tabs):
                self.log_success("Camera", "Camera and Upload tabs present")
            else:
                self.log_issue("Camera", "Missing Element", "Camera/Upload tabs not found")
            
            # Check for back button
            back_button = self.driver.find_element(By.XPATH, "//button[contains(text(), '←')]")
            if back_button:
                self.log_success("Camera", "Back button present")
        except Exception as e:
            self.log_issue("Camera", "Error", f"Camera page test failed: {str(e)}")
        
        self.check_for_errors("Camera")
    
    def test_home_page(self):
        """Test the home page (requires authentication)"""
        print("\n🧪 Testing Home Page...")
        
        # Simulate authentication
        self.driver.get(self.base_url)
        time.sleep(2)
        
        # Set authenticated state
        self.driver.execute_script("""
            window.sessionStorage.setItem('authenticated', 'true');
            window.sessionStorage.setItem('username', 'TestUser');
            window.sessionStorage.setItem('current_page', 'home');
        """)
        self.driver.refresh()
        time.sleep(3)
        
        # Check if we're on home page
        if "Welcome back" in self.driver.page_source:
            self.log_success("Home", "Home page loaded with welcome message")
        else:
            self.log_issue("Home", "Missing Content", "Welcome message not found")
        
        # Check for stats cards
        try:
            stats = self.driver.find_elements(By.CLASS_NAME, "stat-card")
            if len(stats) >= 4:
                self.log_success("Home", f"Stats cards present ({len(stats)} found)")
            else:
                self.log_issue("Home", "Missing Content", f"Expected 4 stat cards, found {len(stats)}")
        except:
            self.log_issue("Home", "Missing Element", "Stats cards not found")
        
        # Check for action cards
        if "Snap Your Fridge" in self.driver.page_source and "Daily Challenge" in self.driver.page_source:
            self.log_success("Home", "Quick action cards present")
        else:
            self.log_issue("Home", "Missing Content", "Quick action cards not found")
        
        self.check_for_errors("Home")
    
    def test_profile_page(self):
        """Test the profile page"""
        print("\n🧪 Testing Profile Page...")
        
        # Navigate to profile
        self.driver.execute_script("window.sessionStorage.setItem('current_page', 'profile');")
        self.driver.refresh()
        time.sleep(3)
        
        # Check for profile elements
        if "Account Settings" in self.driver.page_source:
            self.log_success("Profile", "Profile settings section present")
        else:
            self.log_issue("Profile", "Missing Content", "Account settings not found")
        
        # Check for logout button
        try:
            logout_button = self.driver.find_element(By.XPATH, "//button[contains(text(), 'Logout')]")
            self.log_success("Profile", "Logout button present")
        except:
            self.log_issue("Profile", "Missing Element", "Logout button not found")
        
        self.check_for_errors("Profile")
    
    def test_recipes_page(self):
        """Test the recipes page"""
        print("\n🧪 Testing Recipes Page...")
        
        # Navigate to recipes
        self.driver.execute_script("window.sessionStorage.setItem('current_page', 'recipes');")
        self.driver.refresh()
        time.sleep(3)
        
        # Check for recipes content
        if "My Recipe Collection" in self.driver.page_source:
            self.log_success("Recipes", "Recipes page title present")
        else:
            self.log_issue("Recipes", "Missing Content", "Recipes page title not found")
        
        # Check for tabs
        try:
            tabs = self.driver.find_elements(By.XPATH, "//button[@role='tab']")
            tab_texts = [tab.text for tab in tabs]
            if "All Recipes" in tab_texts and "Favorites" in tab_texts:
                self.log_success("Recipes", "Recipe tabs present")
        except:
            self.log_issue("Recipes", "Missing Element", "Recipe tabs not found")
        
        self.check_for_errors("Recipes")
    
    def run_all_tests(self):
        """Run all page tests"""
        print("🚀 Starting SnapChef Page Tests...")
        print("=" * 50)
        
        self.test_landing_page()
        self.test_auth_page()
        self.test_camera_page()
        self.test_home_page()
        self.test_profile_page()
        self.test_recipes_page()
        
        print("\n" + "=" * 50)
        print("📊 Test Summary")
        print("=" * 50)
        
        if self.issues:
            print(f"\n❌ Found {len(self.issues)} issues:\n")
            for issue in self.issues:
                print(f"  • [{issue['page']}] {issue['type']}: {issue['description']}")
        else:
            print("\n✅ All tests passed! No issues found.")
        
        self.driver.quit()
        return self.issues

def main():
    """Main function to run tests"""
    # Check if Streamlit is running
    try:
        import requests
        response = requests.get("http://localhost:8501")
        if response.status_code != 200:
            print("❌ Streamlit app is not running. Please start it first with: streamlit run app.py")
            sys.exit(1)
    except:
        print("❌ Cannot connect to Streamlit app. Please start it first with: streamlit run app.py")
        sys.exit(1)
    
    # Run tests
    tester = SnapChefTester(headless=False)  # Set to True for headless mode
    issues = tester.run_all_tests()
    
    # Exit with error code if issues found
    sys.exit(1 if issues else 0)

if __name__ == "__main__":
    main()