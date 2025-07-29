#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'SnapChef.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.find { |t| t.name == 'SnapChef' }

# Get the main group (SnapChef folder)
main_group = project.main_group['SnapChef']

# Create or get the Features group
features_group = main_group['Features'] || main_group.new_group('Features')

# Files to add organized by feature
files_to_add = {
  'Camera' => [
    'CameraTabView.swift',
    'CapturedImageView.swift'
  ],
  'Sharing' => [
    'ShareGeneratorView.swift',
    'SocialShareView.swift',
    'SocialShareManager.swift'
  ],
  'Gamification' => [
    'GamificationManager.swift',
    'ChallengesView.swift',
    'LeaderboardView.swift'
  ],
  'AIPersonality' => [
    'AIPersonalityManager.swift',
    'AIPersonalityView.swift',
    'MysteryMealView.swift'
  ]
}

# Add files to the project
files_to_add.each do |feature_name, files|
  # Create or get the feature group
  feature_group = features_group[feature_name] || features_group.new_group(feature_name)
  
  files.each do |filename|
    file_path = "SnapChef/Features/#{feature_name}/#{filename}"
    
    # Check if file exists
    if File.exist?(file_path)
      # Check if file is already in the project
      existing_ref = feature_group.files.find { |f| f.path&.end_with?(filename) }
      
      if existing_ref
        puts "✓ #{filename} already in project"
      else
        # Add file reference
        file_ref = feature_group.new_reference(file_path)
        
        # Add to target
        target.add_file_references([file_ref])
        
        puts "✓ Added #{filename} to project"
      end
    else
      puts "✗ File not found: #{file_path}"
    end
  end
end

# Save the project
project.save

puts "\n✅ Project updated successfully!"
puts "Now you can build the project in Xcode."