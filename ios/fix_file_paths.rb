#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project = Xcodeproj::Project.open('SnapChef.xcodeproj')

puts "Fixing file paths..."
files_fixed = 0

project.files.each do |file_ref|
  if file_ref.path && file_ref.path.include?('SnapChef/Features/')
    # Extract just the filename
    filename = File.basename(file_ref.path)
    
    # Determine correct path based on directory structure
    correct_path = case filename
    when 'EnhancedCameraView.swift'
      'Features/Camera/EnhancedCameraView.swift'
    when 'EnhancedProfileView.swift'
      'Features/Profile/EnhancedProfileView.swift'
    when 'EnhancedShareSheet.swift'
      'Features/Share/EnhancedShareSheet.swift'
    when 'EnhancedRecipeResultsView.swift'
      'Features/Recipes/EnhancedRecipeResultsView.swift'
    else
      next # Skip if we don't know where it should go
    end
    
    if File.exist?(correct_path)
      puts "  Fixed: #{file_ref.path} -> #{correct_path}"
      file_ref.path = correct_path
      files_fixed += 1
    else
      puts "  Warning: #{correct_path} does not exist"
    end
  end
end

# Save the project
project.save

puts "\nFixed #{files_fixed} file paths"
puts "File paths corrected!"