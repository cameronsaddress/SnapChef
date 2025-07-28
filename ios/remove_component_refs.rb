#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project = Xcodeproj::Project.open('SnapChef.xcodeproj')
target = project.targets.first

# Files to remove from Components folder
component_files = [
  'GradientBackground.swift',
  'FloatingFoodAnimation.swift'
]

# Remove file references
files_removed = []
project.files.each do |file_ref|
  if file_ref.path && file_ref.path.include?('Components/')
    puts "Removing reference: #{file_ref.path}"
    
    # Remove from build phases
    target.source_build_phase.files.each do |build_file|
      if build_file.file_ref == file_ref
        target.source_build_phase.remove_file_reference(build_file.file_ref)
      end
    end
    
    # Remove from project
    file_ref.remove_from_project
    files_removed << file_ref.path
  end
end

# Also check for specific files that might not have Components in path
component_files.each do |filename|
  project.files.each do |file_ref|
    if file_ref.path && file_ref.path.end_with?(filename)
      puts "Removing reference: #{file_ref.path}"
      
      # Remove from build phases
      target.source_build_phase.files.each do |build_file|
        if build_file.file_ref == file_ref
          target.source_build_phase.remove_file_reference(build_file.file_ref)
        end
      end
      
      # Remove from project
      file_ref.remove_from_project
      files_removed << file_ref.path unless files_removed.include?(file_ref.path)
    end
  end
end

# Save project
project.save

puts "\nRemoved #{files_removed.count} file references:"
files_removed.each { |f| puts "  - #{f}" }
puts "\nProject cleaned successfully!"