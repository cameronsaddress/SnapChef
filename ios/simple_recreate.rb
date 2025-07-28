#!/usr/bin/env ruby

require 'xcodeproj'

puts "Creating a simple fresh Xcode project..."

begin
  # Create new project
  project = Xcodeproj::Project.new('SnapChef.xcodeproj')

  # Create the main target
  target = project.new_target(:application, 'SnapChef', :ios, '16.0')

  # Configure basic target settings
  target.build_configurations.each do |config|
    config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.snapchef.app'
    config.build_settings['SWIFT_VERSION'] = '5.0'
    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
    config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  end

  # Create basic group structure
  snapchef_group = project.main_group.new_group('SnapChef')
  app_group = snapchef_group.new_group('App')
  
  # Add just the essential files first
  essential_files = [
    'SnapChef/App/SnapChefApp.swift',
    'SnapChef/App/ContentView.swift'
  ]
  
  essential_files.each do |file_path|
    if File.exist?(file_path)
      file_ref = app_group.new_reference(file_path)
      target.source_build_phase.add_file_reference(file_ref)
      puts "Added: #{file_path}"
    end
  end

  # Save project
  project.save
  
  puts "Basic project created successfully!"
  puts "Now open SnapChef.xcodeproj in Xcode and manually add the remaining files"
  
rescue => e
  puts "Error creating project: #{e.message}"
  puts e.backtrace
end