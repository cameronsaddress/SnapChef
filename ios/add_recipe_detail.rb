#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project = Xcodeproj::Project.open('SnapChef.xcodeproj')
target = project.targets.first

# Find the Recipes group
features_group = project.main_group['SnapChef']['Features']
recipes_group = features_group['Recipes']

# Add RecipeDetailView.swift
file_path = 'SnapChef/Features/Recipes/RecipeDetailView.swift'
if File.exist?(file_path)
  file_ref = recipes_group.new_reference(file_path)
  target.source_build_phase.add_file_reference(file_ref)
  puts "Added: #{file_path}"
else
  puts "File not found: #{file_path}"
end

# Save project
project.save
puts "Project updated successfully!"