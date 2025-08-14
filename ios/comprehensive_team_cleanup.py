#!/usr/bin/env python3

import os
import re

def remove_team_references(file_path):
    """Remove Team-related code from specific files."""
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    original_content = content
    
    # CloudKitSchema.swift - Remove Team struct and TeamMessage struct
    if 'CloudKitSchema.swift' in file_path:
        # Remove Team struct
        content = re.sub(r'struct Team \{[^}]*\}', '', content, flags=re.DOTALL)
        # Remove TeamMessage struct  
        content = re.sub(r'// TeamMessage Fields\s*struct TeamMessage \{[^}]*\}', '', content, flags=re.DOTALL)
    
    # CloudKitSyncService.swift - Remove createTeam function
    if 'CloudKitSyncService.swift' in file_path:
        content = re.sub(r'func createTeam\([^}]*?\n    \}', '', content, flags=re.DOTALL)
    
    # CloudKitModels.swift - Remove team property
    if 'CloudKitModels.swift' in file_path:
        content = re.sub(r'let team: Team.*?\n', '', content)
    
    # ChallengeSharingManager.swift - Remove TeamAchievement cases and struct
    if 'ChallengeSharingManager.swift' in file_path:
        # Remove teamAchievement case
        content = re.sub(r'case teamAchievement\(Team, TeamAchievement\).*?\n', '', content)
        # Remove TeamAchievementShareView struct
        content = re.sub(r'struct TeamAchievementShareView: View \{.*?^}', '', content, flags=re.DOTALL | re.MULTILINE)
        # Remove TeamAchievement type references
        content = re.sub(r'let team: Team.*?\n', '', content)
        content = re.sub(r'let achievement: TeamAchievement.*?\n', '', content)
    
    # StreakModels.swift - Remove TeamStreak struct
    if 'StreakModels.swift' in file_path:
        content = re.sub(r'struct TeamStreak[^}]*\{[^}]*\}', '', content, flags=re.DOTALL)
    
    if content != original_content:
        with open(file_path, 'w') as f:
            f.write(content)
        print(f"✅ Cleaned {os.path.basename(file_path)}")
        return True
    return False

# Files to clean
files_to_clean = [
    '/Users/cameronanderson/SnapChef/snapchef/ios/SnapChef/Core/Services/CloudKitSchema.swift',
    '/Users/cameronanderson/SnapChef/snapchef/ios/SnapChef/Core/Services/CloudKitSyncService.swift',
    '/Users/cameronanderson/SnapChef/snapchef/ios/SnapChef/Core/Services/CloudKitModels.swift',
    '/Users/cameronanderson/SnapChef/snapchef/ios/SnapChef/Features/Gamification/ChallengeSharingManager.swift',
    '/Users/cameronanderson/SnapChef/snapchef/ios/SnapChef/Core/Models/StreakModels.swift'
]

cleaned_count = 0
for file_path in files_to_clean:
    if os.path.exists(file_path):
        if remove_team_references(file_path):
            cleaned_count += 1
    else:
        print(f"⚠️  File not found: {os.path.basename(file_path)}")

print(f"\n📊 Cleaned {cleaned_count} files")