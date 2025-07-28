#!/usr/bin/env ruby

require 'xcodeproj'

puts "Fixing duplicate GUIDs in Xcode project..."

begin
  # Try to open and fix the project
  project = Xcodeproj::Project.open('SnapChef.xcodeproj')
  
  # Get all objects and their UUIDs
  uuid_map = {}
  duplicates = []
  
  project.objects.each do |obj|
    uuid = obj.uuid
    if uuid_map[uuid]
      duplicates << uuid
      puts "Found duplicate UUID: #{uuid} for #{obj.class.name}"
    else
      uuid_map[uuid] = obj
    end
  end
  
  if duplicates.any?
    puts "Found #{duplicates.count} duplicate UUIDs. This requires manual fixing."
    puts "Creating a backup and attempting to fix..."
    
    # Create backup
    system("cp -r SnapChef.xcodeproj SnapChef.xcodeproj.backup")
    puts "Backup created: SnapChef.xcodeproj.backup"
    
    # Try to regenerate UUIDs for duplicates
    duplicates.each do |dup_uuid|
      matching_objects = project.objects.select { |obj| obj.uuid == dup_uuid }
      
      # Keep the first one, regenerate UUIDs for the rest
      matching_objects[1..-1].each do |obj|
        old_uuid = obj.uuid
        new_uuid = Xcodeproj::Project::Object::AbstractObject.generate_uuid
        
        # This is a deep fix - we need to update references too
        puts "Regenerating UUID for #{obj.class.name}: #{old_uuid} -> #{new_uuid}"
        
        # Update the object's UUID
        obj.instance_variable_set(:@uuid, new_uuid)
      end
    end
    
    # Save the project
    project.save
    puts "Project saved with regenerated UUIDs"
    
  else
    puts "No duplicate UUIDs found"
  end
  
rescue => e
  puts "Error: #{e.message}"
  puts "\nThe project file is severely corrupted. Let's create a fresh one..."
  
  # If the project can't be opened, we need to recreate it
  puts "Creating a new Xcode project..."
  
  # Back up the corrupted project
  system("mv SnapChef.xcodeproj SnapChef.xcodeproj.corrupted")
  
  # Create a new project
  new_project = Xcodeproj::Project.new('SnapChef.xcodeproj')
  
  # Create the main target
  target = new_project.new_target(:application, 'SnapChef', :ios, '16.0')
  
  # Set up basic configuration
  target.build_configurations.each do |config|
    config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.snapchef.app'
    config.build_settings['DEVELOPMENT_TEAM'] = 'FAKETEAMID'
    config.build_settings['SWIFT_VERSION'] = '5.0'
    config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  end
  
  # Create basic group structure
  snapchef_group = new_project.main_group.new_group('SnapChef')
  
  # Add basic files and groups
  app_group = snapchef_group.new_group('App')
  core_group = snapchef_group.new_group('Core')
  features_group = snapchef_group.new_group('Features')
  design_group = snapchef_group.new_group('Design')
  
  # Add subgroups to core
  core_group.new_group('Models')
  core_group.new_group('ViewModels') 
  core_group.new_group('Services')
  core_group.new_group('Networking')
  core_group.new_group('Utilities')
  
  # Add subgroups to features
  features_group.new_group('Home')
  features_group.new_group('Camera')
  features_group.new_group('Recipes')
  features_group.new_group('Profile')
  features_group.new_group('Share')
  features_group.new_group('Authentication')
  features_group.new_group('Sharing')
  
  # Add subgroups to design
  design_group.new_group('Components')
  
  # Save the new project
  new_project.save
  
  puts "New project created successfully!"
  puts "You'll need to manually re-add your files to the new project."
end