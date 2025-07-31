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
  'Core/Services' => [
    'SnapChef/Core/Services/SubscriptionManager.swift',
    'SnapChef/Core/Services/AnalyticsManager.swift'
  ],
  'Features/Authentication' => [
    'SnapChef/Features/Authentication/PremiumUpgradePrompt.swift',
    'SnapChef/Features/Authentication/SubscriptionView.swift'
  ],
  'Design' => [
    'SnapChef/Design/SnapchefLogo.swift'
  ],
  'Resources' => [
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
        
        # Add to target - check if it's a resource or source file
        if file_path.end_with?('.jpg', '.png', '.jpeg', '.gif', '.pdf', '.json')
          target.resources_build_phase.add_file_reference(file_ref)
          puts "Added to resources: #{file_path}"
        else
          target.source_build_phase.add_file_reference(file_ref)
          puts "Added to sources: #{file_path}"
        end
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