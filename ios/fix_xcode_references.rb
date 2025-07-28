#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project = Xcodeproj::Project.open('SnapChef.xcodeproj')
target = project.targets.first

# Files to remove (incorrect paths)
files_to_remove = [
  'EnhancedProfileView.swift',
  'EnhancedShareSheet.swift', 
  'EnhancedCameraView.swift'
]

# Remove file references
files_removed = []
project.files.each do |file_ref|
  if files_to_remove.any? { |name| file_ref.path == name }
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

# Save project
project.save

puts "\nRemoved #{files_removed.count} file references:"
files_removed.each { |f| puts "  - #{f}" }
puts "\nProject cleaned successfully!"