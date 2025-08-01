#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project_path = 'SnapChef.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Get the main target
target = project.targets.first

# Files to add with their group paths
files_to_add = {
  'Core/Services' => [
    'SnapChef/Core/Services/CloudKitManager.swift'
  ],
  'Features/Gamification' => [
    'SnapChef/Features/Gamification/ChallengeGenerator.swift',
    'SnapChef/Features/Gamification/ChallengeProgressTracker.swift',
    'SnapChef/Features/Gamification/ChallengeService.swift',
    'SnapChef/Features/Gamification/RewardSystem.swift',
    'SnapChef/Features/Gamification/ChefCoinsManager.swift',
    'SnapChef/Features/Gamification/ChallengeRewardAnimator.swift',
    'SnapChef/Features/Gamification/UnlockablesStore.swift',
    'SnapChef/Features/Gamification/ChallengeNotificationManager.swift',
    'SnapChef/Features/Gamification/TeamChallengeManager.swift',
    'SnapChef/Features/Gamification/ChallengeSharingManager.swift',
    'SnapChef/Features/Gamification/ChallengeAnalytics.swift'
  ],
  'Features/Gamification/Views' => [
    'SnapChef/Features/Gamification/Views/ChallengeHubView.swift',
    'SnapChef/Features/Gamification/Views/ChallengeCardView.swift',
    'SnapChef/Features/Gamification/Views/DailyCheckInView.swift',
    'SnapChef/Features/Gamification/Views/AchievementGalleryView.swift',
    'SnapChef/Features/Gamification/Views/LeaderboardView.swift'
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
added_files = []
already_exists = []

files_to_add.each do |group_path, files|
  group = find_or_create_group(project, group_path)
  
  files.each do |file_path|
    # Check if file already exists in project
    file_name = File.basename(file_path)
    existing_file = group.children.find { |child| child.name == file_name }
    
    if existing_file
      already_exists << file_path
    else
      # Add file to group
      file_ref = group.new_file(file_path)
      
      # Add file to target (only for .swift files)
      if file_path.end_with?('.swift')
        target.source_build_phase.add_file_reference(file_ref)
      elsif file_path.end_with?('.xcdatamodeld')
        target.resources_build_phase.add_file_reference(file_ref)
      end
      
      added_files << file_path
    end
  end
end

# Also need to add Core Data model
core_models_group = find_or_create_group(project, 'Core/Models')
model_file = 'SnapChef/Core/Models/ChallengeModels.xcdatamodeld'
if File.exist?(model_file)
  existing_model = core_models_group.children.find { |child| child.name == 'ChallengeModels.xcdatamodeld' }
  if !existing_model
    file_ref = core_models_group.new_file(model_file)
    target.resources_build_phase.add_file_reference(file_ref)
    added_files << model_file
  else
    already_exists << model_file
  end
end

# Save the project
project.save

# Print results
puts "\nFiles added to project:"
added_files.each { |f| puts "  ✓ #{f}" }

if already_exists.any?
  puts "\nAlready exists:"
  already_exists.each { |f| puts "  - #{f}" }
end

puts "\nProject updated successfully!"
puts "Please open SnapChef.xcodeproj in Xcode to verify the changes."