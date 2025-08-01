#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'SnapChef.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.find { |t| t.name == 'SnapChef' }

# Get the Services group
main_group = project.main_group['SnapChef']
core_group = main_group['Core'] || main_group.new_group('Core')
services_group = core_group['Services'] || core_group.new_group('Services')

# Add CloudKitModels.swift
file_path = 'SnapChef/Core/Services/CloudKitModels.swift'
file_ref = services_group.new_file(file_path)

# Add to build phase
build_phase = target.source_build_phase
unless build_phase.files_references.include?(file_ref)
  build_phase.add_file_reference(file_ref)
end

# Save the project
project.save

puts "✅ Added CloudKitModels.swift to Xcode project"