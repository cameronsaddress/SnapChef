#!/usr/bin/env python3

import re

# Read the project file
with open('SnapChef.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# Remove all references to SnapChef.xcodeproj being included as a source file
# These are the problematic lines
lines_to_remove = [
    '0A86A7D231C9755B519CFBD5 /* SnapChef.xcodeproj in Sources */',
    'DFFEF671CD14F671876CC91F /* SnapChef.xcodeproj in Sources */',
    'E1B44DA775CAB3D2D82E4505 /* SnapChef.xcodeproj in Sources */',
    'DC46189F99DD0B16542535C4 /* SnapChef.xcodeproj */',
    '5A4D08EED38A48531DBA4ADC /* SnapChef.xcodeproj */',
    'DAB89B7B6AADB9EDA1F12B38 /* SnapChef.xcodeproj */',
]

# Remove lines containing these references
lines = content.split('\n')
filtered_lines = []
for line in lines:
    should_keep = True
    for pattern in lines_to_remove:
        if pattern in line:
            print(f"Removing line: {line.strip()}")
            should_keep = False
            break
    if should_keep:
        filtered_lines.append(line)

# Join back together
cleaned_content = '\n'.join(filtered_lines)

# Write back to file
with open('SnapChef.xcodeproj/project.pbxproj', 'w') as f:
    f.write(cleaned_content)

print("\n✅ Cleaned project file")
print("Removed self-referencing SnapChef.xcodeproj entries")
print("Now try opening and building in Xcode")