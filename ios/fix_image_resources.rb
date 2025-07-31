#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'SnapChef.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Images to fix
image_files = [
  'SnapChef/Resources/fridge1.jpg',
  'SnapChef/Resources/fridge2.jpg',
  'SnapChef/Resources/fridge3.jpg',
  'SnapChef/Resources/fridge4.jpg',
  'SnapChef/Resources/fridge5.jpg',
  'SnapChef/Resources/meal1.jpg',
  'SnapChef/Resources/meal2.jpg',
  'SnapChef/Resources/meal3.jpg',
  'SnapChef/Resources/meal4.jpg',
  'SnapChef/Resources/meal5.jpg'
]

# First, remove from source build phase if they exist there
image_files.each do |file_path|
  file_ref = project.files.find { |f| f.path == file_path }
  if file_ref
    # Remove from source build phase
    source_file = target.source_build_phase.files.find { |f| f.file_ref == file_ref }
    if source_file
      target.source_build_phase.remove_file_reference(file_ref)
      puts "Removed #{file_path} from source build phase"
    end
    
    # Add to resources build phase if not already there
    resource_file = target.resources_build_phase.files.find { |f| f.file_ref == file_ref }
    if resource_file.nil?
      target.resources_build_phase.add_file_reference(file_ref)
      puts "Added #{file_path} to resources build phase"
    else
      puts "#{file_path} already in resources build phase"
    end
  else
    puts "Warning: #{file_path} not found in project"
  end
end

# Save the project
project.save

puts "\nFixed image resources!"
puts "Please clean and rebuild the project in Xcode."