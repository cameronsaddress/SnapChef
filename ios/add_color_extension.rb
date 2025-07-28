#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project = Xcodeproj::Project.open('SnapChef.xcodeproj')
target = project.targets.first

# Find the Design group
design_group = project.main_group.find_subpath('SnapChef/Design', true)

# First remove any existing reference
project.files.each do |file_ref|
  if file_ref.path && file_ref.path.end_with?('ColorExtensions.swift')
    puts "Removing existing reference: #{file_ref.path}"
    
    # Remove from build phases
    target.source_build_phase.files.each do |build_file|
      if build_file.file_ref == file_ref
        target.source_build_phase.remove_file_reference(build_file.file_ref)
      end
    end
    
    # Remove from project
    file_ref.remove_from_project
  end
end

# Add the file with relative path from Design folder
file_ref = design_group.new_reference('SnapChef/Design/ColorExtensions.swift')
file_ref.path = 'ColorExtensions.swift'  # This is the path relative to the group
file_ref.source_tree = '<group>'

# Add to build phase
target.add_file_references([file_ref])

# Save project
project.save

puts "Added ColorExtensions.swift to project successfully!"