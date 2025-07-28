#!/usr/bin/env ruby

# This script helps add the new Enhanced files to the Xcode project
# Run it with: ruby add_files_to_xcode.rb

require 'xcodeproj'

# Open the project
project_path = 'SnapChef.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Files to add with their group paths
files_to_add = {
  'Design/Components' => [
    'Design/Components/MagicalBackground.swift',
    'Design/Components/GlassmorphicComponents.swift',
    'Design/Components/MorphingTabBar.swift',
    'Design/Components/MagicalTransitions.swift'
  ],
  'Features/Home' => [
    'Features/Home/EnhancedHomeView.swift'
  ],
  'Features/Camera' => [
    'Features/Camera/EnhancedCameraView.swift'
  ],
  'Features/Recipes' => [
    'Features/Recipes/EnhancedRecipesView.swift',
    'Features/Recipes/EnhancedRecipeResultsView.swift'
  ],
  'Features/Profile' => [
    'Features/Profile/EnhancedProfileView.swift'
  ],
  'Features/Share' => [
    'Features/Share/EnhancedShareSheet.swift'
  ]
}

# Function to find or create group
def find_or_create_group(project, path)
  groups = path.split('/')
  current_group = project.main_group['SnapChef']
  
  groups.each do |group_name|
    existing_group = current_group.children.find { |child| child.name == group_name }
    if existing_group
      current_group = existing_group
    else
      current_group = current_group.new_group(group_name)
    end
  end
  
  current_group
end

# Add files to project
files_to_add.each do |group_path, files|
  group = find_or_create_group(project, group_path)
  
  files.each do |file_path|
    # Check if file exists
    full_path = File.join(Dir.pwd, file_path)
    if File.exist?(full_path)
      # Check if file is already in project
      file_ref = project.files.find { |f| f.path == file_path }
      
      if file_ref.nil?
        # Add file reference
        file_ref = group.new_file(file_path)
        
        # Add to target
        target.source_build_phase.add_file_reference(file_ref)
        
        puts "Added: #{file_path}"
      else
        puts "Already exists: #{file_path}"
      end
    else
      puts "File not found: #{full_path}"
    end
  end
end

# Save the project
project.save

puts "\nProject updated successfully!"
puts "Please open SnapChef.xcodeproj in Xcode to verify the changes."