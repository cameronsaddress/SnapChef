#!/bin/bash

# This script uses xcodebuild to properly remove package dependencies
# Note: This requires Xcode command line tools

echo "Removing Google Sign-In package dependency..."

# First, let's try to resolve packages without Google Sign-In
# This may fail but it's worth trying
xcodebuild -resolvePackageDependencies -project SnapChef.xcodeproj -clonedSourcePackagesDirPath DerivedData 2>/dev/null || true

# Clean all caches
echo "Cleaning build artifacts and caches..."
xcodebuild clean -project SnapChef.xcodeproj -alltargets 2>/dev/null || true
rm -rf ~/Library/Developer/Xcode/DerivedData/SnapChef-*
rm -rf ~/Library/Caches/com.apple.dt.Xcode/ModuleCache.noindex/

echo "✅ Done. Please:"
echo "1. Open SnapChef.xcodeproj in Xcode"  
echo "2. Go to Project Navigator → SnapChef → Package Dependencies"
echo "3. Remove GoogleSignIn-iOS if it appears"
echo "4. Clean Build Folder (Shift+Cmd+K)"
echo "5. Build the project"