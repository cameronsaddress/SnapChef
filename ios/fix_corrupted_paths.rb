#!/usr/bin/env ruby

require 'xcodeproj'

# Open the project
project = Xcodeproj::Project.open('SnapChef.xcodeproj')

puts "Fixing corrupted file paths..."
files_fixed = 0

project.files.each do |file_ref|
  if file_ref.path && file_ref.path.include?('SnapChef/Features/SnapChef/')
    # This is a corrupted path - fix it
    original_path = file_ref.path
    
    # Remove the duplicate "SnapChef/" part
    correct_path = original_path.gsub('SnapChef/Features/SnapChef/', 'SnapChef/Features/')
    
    puts "  Fixing: #{original_path}"
    puts "    -> #{correct_path}"
    
    # Verify the correct path exists
    if File.exist?(correct_path)
      file_ref.path = correct_path
      files_fixed += 1
      puts "    ✓ Fixed"
    else
      puts "    ✗ File not found at corrected path"
    end
  end
end

# Also check for any other corrupted paths
project.files.each do |file_ref|
  if file_ref.path && file_ref.path.include?('SnapChef/SnapChef/')
    # This is also a corrupted path
    original_path = file_ref.path
    correct_path = original_path.gsub('SnapChef/SnapChef/', 'SnapChef/')
    
    puts "  Fixing: #{original_path}"
    puts "    -> #{correct_path}"
    
    if File.exist?(correct_path)
      file_ref.path = correct_path
      files_fixed += 1
      puts "    ✓ Fixed"
    else
      puts "    ✗ File not found at corrected path"
    end
  end
end

# Save the project
project.save

puts "\nFixed #{files_fixed} corrupted file paths"
puts "Paths corrected!"