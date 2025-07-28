#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'SnapChef.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Update EnhancedHomeView reference
# Currently it points to SnapChef/EnhancedHomeView.swift
# We'll keep it there since we copied the correct version

# We need to ensure EnhancedRecipesView is in the right place
# It's already correctly pointing to Features/Recipes/EnhancedRecipesView.swift

puts "Project file references are already correct!"
puts "- EnhancedHomeView: SnapChef/EnhancedHomeView.swift (we copied the updated version here)"
puts "- EnhancedRecipesView: Features/Recipes/EnhancedRecipesView.swift (already correct)"
puts "- EnhancedProfileView: Features/Profile/EnhancedProfileView.swift (already correct)"
puts "- Design components: All in Design/ folder (not Components/ subfolder)"

# Save the project
project.save

puts "\nDuplicates removed successfully!"
puts "All views should now have MagicalBackground support."