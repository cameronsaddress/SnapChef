#!/usr/bin/env python3

import re
import sys

def remove_team_code(file_path):
    """Remove all Team-related code from a Swift file."""
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    # Find and remove the Team Methods section in CloudKitManager
    if 'CloudKitManager.swift' in file_path:
        # Remove from "// MARK: - Team Methods" to the next "// MARK:" or end of class
        pattern = r'// MARK: - Team Methods.*?(?=// MARK:|^}$|\Z)'
        content = re.sub(pattern, '', content, flags=re.DOTALL | re.MULTILINE)
        
        # Remove teamFromRecord method
        pattern = r'private func teamFromRecord\(.*?\n    \}'
        content = re.sub(pattern, '', content, flags=re.DOTALL)
        
        # Remove sendTeamChatMessage method
        pattern = r'func sendTeamChatMessage\(.*?\n    \}'
        content = re.sub(pattern, '', content, flags=re.DOTALL)
    
    # Save the modified content
    with open(file_path, 'w') as f:
        f.write(content)
    
    print(f"✅ Cleaned {file_path}")

# Process CloudKitManager.swift
remove_team_code('/Users/cameronanderson/SnapChef/snapchef/ios/SnapChef/Core/Services/CloudKitManager.swift')