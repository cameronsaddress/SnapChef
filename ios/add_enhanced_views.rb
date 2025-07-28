#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project = Xcodeproj::Project.open('SnapChef.xcodeproj')
target = project.targets.first

# Find the Features group
features_group = project.main_group.find_subpath('SnapChef/Features')

# Files to add with their correct paths
files_to_add = [
  { path: 'SnapChef/Features/Camera/EnhancedCameraView.swift', group: 'Camera' },
  { path: 'SnapChef/Features/Profile/EnhancedProfileView.swift', group: 'Profile' },
  { path: 'SnapChef/Features/Share/EnhancedShareSheet.swift', group: 'Share' },
  { path: 'SnapChef/Features/Recipes/EnhancedRecipeResultsView.swift', group: 'Recipes' }
]

files_added = []

files_to_add.each do |file_info|
  file_path = file_info[:path]
  group_name = file_info[:group]
  
  # Skip if file already exists in project
  next if project.files.any? { |f| f.path == file_path }
  
  # Find the appropriate subgroup
  subgroup = features_group.find_subpath(group_name) || features_group
  
  # Add file reference
  file_ref = subgroup.new_reference(file_path)
  
  # Add to build phase
  target.source_build_phase.add_file_reference(file_ref)
  
  files_added << file_path
  puts "Added: #{file_path}"
end

# Save project
project.save

puts "\nAdded #{files_added.count} file references:"
files_added.each { |f| puts "  - #{f}" }
puts "\nProject updated successfully!"