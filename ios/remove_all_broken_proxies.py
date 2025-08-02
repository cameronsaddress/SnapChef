#!/usr/bin/env python3

import re

# Read the project file
with open('SnapChef.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# Find all broken container proxy IDs
broken_proxy_ids = ['07E8BBB928DD85AC71554922', '3D19831EF23E087ACB982CB6', 
                    '48A899BDD616A0DC45BC4A66', '915CA52C2C8EF5B1400B4D55',
                    'B7F85619EC41EDE7030B62B5']

# Remove all sections and references to these proxies
lines = content.split('\n')
cleaned_lines = []
skip_section = False
brace_count = 0

for line in lines:
    # Check if this line starts a broken proxy section
    if any(proxy_id in line for proxy_id in broken_proxy_ids):
        if 'PBXContainerItemProxy' in line and '= {' in line:
            print(f"Removing proxy section: {line.strip()}")
            skip_section = True
            brace_count = line.count('{') - line.count('}')
            continue
        elif 'remoteRef' in line or 'proxyType' in line or 'remoteGlobalIDString' in line:
            print(f"Removing proxy reference: {line.strip()}")
            continue
    
    if skip_section:
        brace_count += line.count('{') - line.count('}')
        if brace_count <= 0:
            skip_section = False
        continue
    
    cleaned_lines.append(line)

# Write back
with open('SnapChef.xcodeproj/project.pbxproj', 'w') as f:
    f.write('\n'.join(cleaned_lines))

print("\n✅ Removed all broken proxy references")
print("Try cleaning now")