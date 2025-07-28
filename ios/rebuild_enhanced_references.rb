#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project = Xcodeproj::Project.open('SnapChef.xcodeproj')
target = project.targets.first

puts "Removing all Enhanced view references..."

# First, remove all existing Enhanced view references
enhanced_files = []
project.files.each do |file_ref|
  if file_ref.path && file_ref.path.include?('Enhanced')
    enhanced_files << file_ref
  end
end

enhanced_files.each do |file_ref|
  puts "  Removing: #{file_ref.path}"
  
  # Remove from build phases
  target.source_build_phase.files.each do |build_file|
    if build_file.file_ref == file_ref
      target.source_build_phase.remove_file_reference(build_file.file_ref)
    end
  end
  
  # Remove from project
  file_ref.remove_from_project
end

# Now add them back with correct paths
puts "\nAdding Enhanced views with correct paths..."

# Get the Features group
features_group = project.main_group['SnapChef']['Features']

# Define the Enhanced views and their correct locations
enhanced_views = [
  { file: 'EnhancedHomeView.swift', group: 'Home' },
  { file: 'EnhancedCameraView.swift', group: 'Camera' },
  { file: 'EnhancedRecipesView.swift', group: 'Recipes' },
  { file: 'EnhancedRecipeResultsView.swift', group: 'Recipes' },
  { file: 'EnhancedProfileView.swift', group: 'Profile' },
  { file: 'EnhancedShareSheet.swift', group: 'Share' }
]

enhanced_views.each do |view|
  filename = view[:file]
  group_name = view[:group]
  
  # Find the actual file on disk
  file_path = Dir.glob("**/#{filename}").find { |p| File.exist?(p) }
  
  if file_path
    puts "  Found #{filename} at: #{file_path}"
    
    # Find or create the appropriate group
    subgroup = features_group.children.find { |g| g.is_a?(Xcodeproj::Project::Object::PBXGroup) && g.display_name == group_name }
    
    if !subgroup
      puts "    Creating #{group_name} group"
      subgroup = features_group.new_group(group_name)
    end
    
    # Add file reference
    file_ref = subgroup.new_reference(file_path)
    
    # Add to build phase
    target.source_build_phase.add_file_reference(file_ref)
    
    puts "    ✓ Added to #{group_name} group"
  else
    puts "  ✗ Could not find #{filename}"
  end
end

# Save project
project.save

puts "\nEnhanced view references rebuilt successfully!"