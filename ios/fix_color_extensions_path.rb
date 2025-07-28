#!/usr/bin/env ruby

require 'xcodeproj'
require 'json'

# Open the project
project = Xcodeproj::Project.open('SnapChef.xcodeproj')
target = project.targets.first

# First remove any existing ColorExtensions reference
files_to_remove = []
project.files.each do |file_ref|
  if file_ref.path && file_ref.path.include?('ColorExtensions.swift')
    puts "Found ColorExtensions reference: #{file_ref.path}"
    puts "  - Full path: #{file_ref.real_path}" rescue nil
    puts "  - UUID: #{file_ref.uuid}"
    
    # Remove from build phases
    target.source_build_phase.files.each do |build_file|
      if build_file.file_ref == file_ref
        puts "  - Removing from build phase"
        target.source_build_phase.remove_file_reference(build_file.file_ref)
      end
    end
    
    # Mark for removal
    files_to_remove << file_ref
  end
end

# Remove the files
files_to_remove.each do |file_ref|
  file_ref.remove_from_project
end

# Find the Design group
design_group = project.main_group.find_subpath('SnapChef/Design', true)
if design_group
  puts "\nFound Design group at path: #{design_group.path}"
  
  # Add ColorExtensions.swift with correct path
  file_ref = design_group.new_file('SnapChef/Design/ColorExtensions.swift')
  
  # Add to build phase
  target.add_file_references([file_ref])
  
  puts "\nAdded ColorExtensions.swift:"
  puts "  - Path: #{file_ref.path}"
  puts "  - Real path: #{file_ref.real_path}" rescue nil
  puts "  - UUID: #{file_ref.uuid}"
else
  puts "ERROR: Could not find Design group!"
end

# Save project
project.save

puts "\nFixed ColorExtensions.swift path in project!"