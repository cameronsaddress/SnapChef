#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project = Xcodeproj::Project.open('SnapChef.xcodeproj')
target = project.targets.first
snapchef_group = project.main_group['SnapChef']

# Find duplicate groups
features_groups = snapchef_group.children.select { |g| g.is_a?(Xcodeproj::Project::Object::PBXGroup) && g.display_name == 'Features' }
design_groups = snapchef_group.children.select { |g| g.is_a?(Xcodeproj::Project::Object::PBXGroup) && g.display_name == 'Design' }

puts "Found #{features_groups.count} Features groups"
puts "Found #{design_groups.count} Design groups"

# If we have duplicates, merge them
if features_groups.count > 1
  puts "\nMerging Features groups..."
  primary_features = features_groups.first
  
  features_groups[1..-1].each do |duplicate_group|
    # Move all children from duplicate to primary
    duplicate_group.children.each do |child|
      if child.is_a?(Xcodeproj::Project::Object::PBXGroup)
        # Check if subgroup already exists in primary
        existing_subgroup = primary_features.children.find { |g| g.is_a?(Xcodeproj::Project::Object::PBXGroup) && g.display_name == child.display_name }
        
        if existing_subgroup
          # Merge contents into existing subgroup
          child.children.each do |subchild|
            subchild.move(existing_subgroup)
            puts "  Moved #{subchild.path || subchild.display_name} to existing #{child.display_name} group"
          end
        else
          # Move entire subgroup
          child.move(primary_features)
          puts "  Moved #{child.display_name} group to primary Features"
        end
      else
        # Move file directly
        child.move(primary_features)
        puts "  Moved #{child.path || child.display_name} to primary Features"
      end
    end
    
    # Remove the duplicate group
    duplicate_group.remove_from_project
    puts "  Removed duplicate Features group"
  end
end

if design_groups.count > 1
  puts "\nMerging Design groups..."
  primary_design = design_groups.first
  
  design_groups[1..-1].each do |duplicate_group|
    # Move all children from duplicate to primary
    duplicate_group.children.each do |child|
      if child.is_a?(Xcodeproj::Project::Object::PBXGroup)
        # Check if subgroup already exists in primary
        existing_subgroup = primary_design.children.find { |g| g.is_a?(Xcodeproj::Project::Object::PBXGroup) && g.display_name == child.display_name }
        
        if existing_subgroup
          # Merge contents into existing subgroup
          child.children.each do |subchild|
            subchild.move(existing_subgroup)
            puts "  Moved #{subchild.path || subchild.display_name} to existing #{child.display_name} group"
          end
        else
          # Move entire subgroup
          child.move(primary_design)
          puts "  Moved #{child.display_name} group to primary Design"
        end
      else
        # Move file directly
        child.move(primary_design)
        puts "  Moved #{child.path || child.display_name} to primary Design"
      end
    end
    
    # Remove the duplicate group
    duplicate_group.remove_from_project
    puts "  Removed duplicate Design group"
  end
end

# Clean up any file references with incorrect paths
puts "\nCleaning up file paths..."
files_fixed = 0

project.files.each do |file_ref|
  if file_ref.path && file_ref.path.start_with?('SnapChef/')
    # This is likely an incorrect path - fix it
    correct_path = file_ref.path.sub(/^SnapChef\//, '')
    if File.exist?(correct_path)
      puts "  Fixed path: #{file_ref.path} -> #{correct_path}"
      file_ref.path = correct_path
      files_fixed += 1
    end
  end
end

# Save the project
project.save

puts "\nFixed #{files_fixed} file paths"
puts "Project structure cleaned up successfully!"