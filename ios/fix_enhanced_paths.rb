#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project = Xcodeproj::Project.open('SnapChef.xcodeproj')

puts "Fixing Enhanced view file paths..."
files_fixed = 0

# Map of incorrect paths to correct paths
path_fixes = {
  'SnapChef/Features/Camera/EnhancedCameraView.swift' => 'SnapChef/Features/Camera/EnhancedCameraView.swift',
  'SnapChef/Features/Profile/EnhancedProfileView.swift' => 'SnapChef/Features/Profile/EnhancedProfileView.swift', 
  'SnapChef/Features/Share/EnhancedShareSheet.swift' => 'SnapChef/Features/Share/EnhancedShareSheet.swift',
  'SnapChef/Features/Recipes/EnhancedRecipeResultsView.swift' => 'SnapChef/Features/Recipes/EnhancedRecipeResultsView.swift'
}

project.files.each do |file_ref|
  if file_ref.path && path_fixes.key?(file_ref.path)
    correct_path = path_fixes[file_ref.path]
    
    if File.exist?(correct_path)
      puts "  Confirmed path exists: #{correct_path}"
      files_fixed += 1
    else
      puts "  ERROR: Path does not exist: #{correct_path}"
    end
  end
end

# Also check for any Enhanced files that might need different treatment
project.files.each do |file_ref|
  if file_ref.path && file_ref.path.include?('Enhanced') && !file_ref.path.start_with?('SnapChef/')
    filename = File.basename(file_ref.path)
    puts "  Found Enhanced file with non-standard path: #{file_ref.path}"
    
    # Look for the actual file
    actual_path = Dir.glob("**/#{filename}").first
    if actual_path && File.exist?(actual_path)
      puts "    -> Should be: #{actual_path}"
      file_ref.path = actual_path
      files_fixed += 1
    end
  end
end

# Save the project
project.save

puts "\nProcessed #{files_fixed} Enhanced view files"
puts "Enhanced view paths verified!"