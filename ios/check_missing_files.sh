#!/bin/bash

echo "Checking for Swift files not in Xcode project..."
echo "================================================"

# Find all Swift files in the project
all_swift_files=$(find ./SnapChef -name "*.swift" | sort)

# Extract files referenced in the project file
project_files=$(grep -o 'path = [^;]*\.swift' SnapChef.xcodeproj/project.pbxproj | sed 's/path = //' | sort | uniq)

echo "Files that may need to be added to Xcode project:"
echo ""

for file in $all_swift_files; do
    # Remove ./ prefix for comparison
    clean_file=${file#./}
    
    # Check if file is in project
    if ! echo "$project_files" | grep -q "$clean_file"; then
        echo "  ❌ $file"
    fi
done

echo ""
echo "To add these files:"
echo "1. Open SnapChef.xcodeproj in Xcode"
echo "2. Right-click the appropriate folder"
echo "3. Select 'Add Files to SnapChef...'"
echo "4. Select the missing files"
echo "5. Ensure 'SnapChef' target is checked"