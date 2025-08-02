#!/usr/bin/env python3

import re

# Read the project file
with open('SnapChef.xcodeproj/project.pbxproj', 'r') as f:
    lines = f.readlines()

# Find and remove broken container item proxy sections
cleaned_lines = []
skip_until_close = False
brace_count = 0

for i, line in enumerate(lines):
    # Check if this is a broken container proxy section
    if 'PBXContainerItemProxy' in line and ('07E8BBB928DD85AC71554922' in line or 
                                            '3D19831EF23E087ACB982CB6' in line or 
                                            '48A899BDD616A0DC45BC4A66' in line):
        print(f"Removing broken proxy section starting at line {i+1}")
        skip_until_close = True
        brace_count = 0
        # Count opening braces on this line
        brace_count += line.count('{')
        brace_count -= line.count('}')
        if brace_count == 0:
            skip_until_close = False
        continue
    
    if skip_until_close:
        brace_count += line.count('{')
        brace_count -= line.count('}')
        if brace_count <= 0:
            skip_until_close = False
        continue
    
    # Also remove reference proxy sections that reference the removed proxies
    if 'remoteRef = 07E8BBB928DD85AC71554922' in line or \
       'remoteRef = 3D19831EF23E087ACB982CB6' in line or \
       'remoteRef = 48A899BDD616A0DC45BC4A66' in line:
        print(f"Removing reference to broken proxy at line {i+1}")
        continue
    
    cleaned_lines.append(line)

# Write back to file
with open('SnapChef.xcodeproj/project.pbxproj', 'w') as f:
    f.writelines(cleaned_lines)

print("\n✅ Fixed container proxy issues")
print("Now try cleaning and building in Xcode")