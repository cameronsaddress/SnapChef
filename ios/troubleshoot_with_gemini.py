#!/usr/bin/env python3
"""
Swift Project Troubleshooter using Google Gemini AI
This script collects all Swift and project files and sends them to Gemini for comprehensive analysis
"""

import os
import sys
import glob
import google.generativeai as genai
from typing import List, Dict, Tuple
import time
from pathlib import Path

# Configure Gemini
API_KEY = os.getenv("GOOGLE_GENERATIVE_AI_API_KEY")
if not API_KEY:
    print("ERROR: GOOGLE_GENERATIVE_AI_API_KEY environment variable not set!")
    print("Please set your Google AI API key as an environment variable:")
    print("export GOOGLE_GENERATIVE_AI_API_KEY='your-api-key-here'")
    sys.exit(1)
    
genai.configure(api_key=API_KEY)

# File extensions to include
INCLUDE_EXTENSIONS = [
    '.swift',
    '.xcodeproj',
    '.plist',
    '.xcdatamodeld',
    '.xcconfig',
    '.storyboard',
    '.xib',
    '.entitlements',
    '.md',
    '.json',
    '.yml',
    '.yaml'
]

# Directories to exclude
EXCLUDE_DIRS = [
    'Pods',
    'DerivedData',
    '.git',
    'build',
    'Build',
    '.DS_Store',
    'xcuserdata',
    'node_modules',
    '__pycache__',
    '.pytest_cache',
    'venv',
    'env'
]

# Files to exclude
EXCLUDE_FILES = [
    '.DS_Store',
    'Package.resolved',
    'Podfile.lock'
]

def should_include_file(file_path: str) -> bool:
    """Check if a file should be included in the analysis"""
    # Check if file has an included extension
    if not any(file_path.endswith(ext) for ext in INCLUDE_EXTENSIONS):
        return False
    
    # Check if file is in an excluded directory
    path_parts = file_path.split(os.sep)
    if any(excluded in path_parts for excluded in EXCLUDE_DIRS):
        return False
    
    # Check if file is in excluded files list
    filename = os.path.basename(file_path)
    if filename in EXCLUDE_FILES:
        return False
    
    return True

def collect_project_files(root_dir: str) -> List[Tuple[str, str]]:
    """Collect all relevant project files and their contents"""
    files_content = []
    total_size = 0
    
    print(f"Scanning directory: {root_dir}")
    
    for dirpath, dirnames, filenames in os.walk(root_dir):
        # Remove excluded directories from search
        dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIRS]
        
        for filename in filenames:
            file_path = os.path.join(dirpath, filename)
            relative_path = os.path.relpath(file_path, root_dir)
            
            if should_include_file(file_path):
                try:
                    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                        content = f.read()
                        total_size += len(content)
                        files_content.append((relative_path, content))
                        print(f"  ✓ Added: {relative_path} ({len(content):,} chars)")
                except Exception as e:
                    print(f"  ✗ Error reading {relative_path}: {e}")
    
    print(f"\nTotal files collected: {len(files_content)}")
    print(f"Total characters: {total_size:,}")
    return files_content

def build_analysis_prompt(files_content: List[Tuple[str, str]]) -> str:
    """Build the comprehensive analysis prompt for Gemini"""
    prompt = """You are a master Swift/iOS developer and expert debugger. You have been given the complete source code of a SnapChef iOS application.

Your task is to:
1. Trace through the entire codebase starting from the app entry point (SnapChefApp.swift)
2. Identify ALL compilation errors, missing properties, type mismatches, and potential runtime issues
3. Pay special attention to:
   - Recipe model and its properties (tags, dietaryInfo, etc.)
   - Core Data entity configurations and generated files
   - Challenge system implementation
   - Any missing method implementations or protocol conformances
   - Build configuration issues

Please provide a comprehensive list of ALL issues found, organized by severity:
- CRITICAL: Compilation errors that prevent building
- HIGH: Runtime errors or missing required implementations
- MEDIUM: Potential issues or code smells
- LOW: Suggestions for improvement

For each issue, provide:
- File path and line number (if applicable)
- Description of the issue
- Suggested fix

Here is the complete project structure and code:

"""
    
    # Add file contents
    for file_path, content in files_content:
        prompt += f"\n\n{'='*80}\nFILE: {file_path}\n{'='*80}\n{content}"
    
    return prompt

def analyze_with_gemini(prompt: str) -> str:
    """Send the prompt to Gemini and get analysis"""
    print("\nSending to Gemini for analysis...")
    
    # Use Gemini 1.5 Pro for large context window
    model = genai.GenerativeModel('gemini-1.5-pro')
    
    try:
        response = model.generate_content(prompt)
        return response.text
    except Exception as e:
        return f"Error during Gemini analysis: {str(e)}"

def save_analysis(analysis: str, output_file: str = "gemini_analysis.md"):
    """Save the analysis to a file"""
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write("# SnapChef iOS Project Analysis by Gemini\n\n")
        f.write(f"Generated on: {time.strftime('%Y-%m-%d %H:%M:%S')}\n\n")
        f.write("---\n\n")
        f.write(analysis)
    print(f"\nAnalysis saved to: {output_file}")

def main():
    """Main function to run the troubleshooter"""
    # Get the iOS project directory
    ios_dir = os.path.dirname(os.path.abspath(__file__))
    
    print("SnapChef iOS Project Troubleshooter")
    print("===================================\n")
    
    # Collect all project files
    files_content = collect_project_files(ios_dir)
    
    if not files_content:
        print("No files found to analyze!")
        return
    
    # Check token limit (rough estimate: 4 chars ≈ 1 token)
    estimated_tokens = sum(len(content) for _, content in files_content) // 4
    print(f"\nEstimated tokens: {estimated_tokens:,}")
    
    if estimated_tokens > 900_000:  # Leave some buffer for response
        print("WARNING: Content may exceed Gemini's context limit!")
        response = input("Continue anyway? (y/n): ")
        if response.lower() != 'y':
            return
    
    # Build the analysis prompt
    prompt = build_analysis_prompt(files_content)
    
    # Analyze with Gemini
    analysis = analyze_with_gemini(prompt)
    
    # Save the analysis
    save_analysis(analysis)
    
    # Also print to console
    print("\n" + "="*80)
    print("ANALYSIS RESULTS")
    print("="*80)
    print(analysis)

if __name__ == "__main__":
    try:
        import google.generativeai
    except ImportError:
        print("Error: google-generativeai package not installed!")
        print("Please run: pip install google-generativeai")
        sys.exit(1)
    
    main()