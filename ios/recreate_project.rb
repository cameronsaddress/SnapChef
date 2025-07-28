#!/usr/bin/env ruby

require 'xcodeproj'

puts "Creating a fresh Xcode project..."

# Create new project
project = Xcodeproj::Project.new('SnapChef.xcodeproj')

# Create the main target
target = project.new_target(:application, 'SnapChef', :ios, '16.0')

# Configure target settings
target.build_configurations.each do |config|
  config.build_settings.merge!({
    'PRODUCT_BUNDLE_IDENTIFIER' => 'com.snapchef.app',
    'DEVELOPMENT_TEAM' => 'FAKETEAMID',
    'SWIFT_VERSION' => '5.0',
    'TARGETED_DEVICE_FAMILY' => '1,2',
    'IPHONEOS_DEPLOYMENT_TARGET' => '16.0',
    'ENABLE_PREVIEWS' => 'YES',
    'ASSETCATALOG_COMPILER_APPICON_NAME' => 'AppIcon',
    'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME' => 'AccentColor',
    'CODE_SIGN_ENTITLEMENTS' => 'SnapChef/SnapChef.entitlements',
    'CODE_SIGN_STYLE' => 'Automatic',
    'CURRENT_PROJECT_VERSION' => '1',
    'GENERATE_INFOPLIST_FILE' => 'YES',
    'INFOPLIST_KEY_UIApplicationSceneManifest_Generation' => 'YES',
    'INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents' => 'YES',
    'INFOPLIST_KEY_UILaunchScreen_Generation' => 'YES',
    'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad' => 'UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight',
    'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone' => 'UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight',
    'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/Frameworks',
    'MARKETING_VERSION' => '1.0',
    'PRODUCT_BUNDLE_IDENTIFIER' => 'com.snapchef.app',
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'SWIFT_EMIT_LOC_STRINGS' => 'YES',
    'SWIFT_VERSION' => '5.0'
  })
end

# Create group structure
snapchef_group = project.main_group.new_group('SnapChef')

# Core groups
app_group = snapchef_group.new_group('App')
core_group = snapchef_group.new_group('Core')
features_group = snapchef_group.new_group('Features') 
design_group = snapchef_group.new_group('Design')
resources_group = snapchef_group.new_group('Resources')
preview_group = snapchef_group.new_group('Preview Content')

# Core subgroups
models_group = core_group.new_group('Models')
viewmodels_group = core_group.new_group('ViewModels')
services_group = core_group.new_group('Services')
networking_group = core_group.new_group('Networking')
utilities_group = core_group.new_group('Utilities')

# Features subgroups
home_group = features_group.new_group('Home')
camera_group = features_group.new_group('Camera')
recipes_group = features_group.new_group('Recipes')
profile_group = features_group.new_group('Profile')
share_group = features_group.new_group('Share')
auth_group = features_group.new_group('Authentication')
sharing_group = features_group.new_group('Sharing')

# Design subgroups
components_group = design_group.new_group('Components')

puts "Adding files to project..."

# Add files to appropriate groups
files_to_add = [
  # App
  { path: 'SnapChef/App/SnapChefApp.swift', group: app_group },
  { path: 'SnapChef/App/ContentView.swift', group: app_group },
  
  # Core - Models
  { path: 'SnapChef/Core/Models/Recipe.swift', group: models_group },
  { path: 'SnapChef/Core/Models/User.swift', group: models_group },
  
  # Core - ViewModels
  { path: 'SnapChef/Core/ViewModels/AppState.swift', group: viewmodels_group },
  
  # Core - Services
  { path: 'SnapChef/Core/Services/AuthenticationManager.swift', group: services_group },
  { path: 'SnapChef/Core/Services/DeviceManager.swift', group: services_group },
  
  # Core - Networking
  { path: 'SnapChef/Core/Networking/NetworkManager.swift', group: networking_group },
  
  # Core - Utilities
  { path: 'SnapChef/Core/Utilities/HapticManager.swift', group: utilities_group },
  { path: 'SnapChef/Core/Utilities/MockDataProvider.swift', group: utilities_group },
  
  # Features - Home
  { path: 'SnapChef/EnhancedHomeView.swift', group: home_group },
  
  # Features - Camera
  { path: 'SnapChef/Features/Camera/CameraModel.swift', group: camera_group },
  { path: 'SnapChef/Features/Camera/CameraView.swift', group: camera_group },
  { path: 'SnapChef/Features/Camera/HomeView.swift', group: camera_group },
  { path: 'SnapChef/Features/Camera/EnhancedCameraView.swift', group: camera_group },
  
  # Features - Recipes
  { path: 'SnapChef/Features/Recipes/RecipeResultsView.swift', group: recipes_group },
  { path: 'SnapChef/Features/Recipes/RecipesView.swift', group: recipes_group },
  { path: 'SnapChef/Features/Recipes/EnhancedRecipesView.swift', group: recipes_group },
  { path: 'SnapChef/Features/Recipes/EnhancedRecipeResultsView.swift', group: recipes_group },
  
  # Features - Profile
  { path: 'SnapChef/Features/Profile/ProfileView.swift', group: profile_group },
  { path: 'SnapChef/Features/Profile/EnhancedProfileView.swift', group: profile_group },
  
  # Features - Share
  { path: 'SnapChef/Features/Share/EnhancedShareSheet.swift', group: share_group },
  
  # Features - Authentication
  { path: 'SnapChef/Features/Authentication/OnboardingView.swift', group: auth_group },
  { path: 'SnapChef/Features/Authentication/SubscriptionView.swift', group: auth_group },
  
  # Features - Sharing
  { path: 'SnapChef/Features/Sharing/PrintView.swift', group: sharing_group },
  { path: 'SnapChef/Features/Sharing/ShareSheet.swift', group: sharing_group },
  
  # Design
  { path: 'SnapChef/Design/MagicalBackground.swift', group: design_group },
  { path: 'SnapChef/Design/GlassmorphicComponents.swift', group: design_group },
  { path: 'SnapChef/Design/MorphingTabBar.swift', group: design_group },
  { path: 'SnapChef/Design/MagicalTransitions.swift', group: design_group },
  
  # Design - Components
  { path: 'SnapChef/Design/Components/FloatingFoodAnimation.swift', group: components_group },
  { path: 'SnapChef/Design/Components/GradientBackground.swift', group: components_group },
  
  # Resources
  { path: 'SnapChef/Design/Assets.xcassets', group: design_group },
  { path: 'SnapChef/Info.plist', group: snapchef_group },
  { path: 'SnapChef/SnapChef.entitlements', group: snapchef_group },
  
  # Preview Content
  { path: 'SnapChef/Preview Content/Preview Assets.xcassets', group: preview_group }
]

files_added = 0
files_to_add.each do |file_info|
  if File.exist?(file_info[:path])
    file_ref = file_info[:group].new_reference(file_info[:path])
    
    # Add Swift files to build phase
    if file_info[:path].end_with?('.swift')
      target.source_build_phase.add_file_reference(file_ref)
    end
    
    # Add asset catalogs to resources
    if file_info[:path].end_with?('.xcassets')
      target.resources_build_phase.add_file_reference(file_ref)
    end
    
    files_added += 1
    puts "  Added: #{file_info[:path]}"
  else
    puts "  Missing: #{file_info[:path]}"
  end
end

# Add package dependencies
puts "Adding package dependencies..."

# GoogleSignIn package
google_signin_url = 'https://github.com/google/GoogleSignIn-iOS'
google_signin_requirement = { :kind => 'upToNextMajorVersion', :minimumVersion => '7.1.0' }
project.add_swift_package_product_dependency(
  target,
  'GoogleSignIn',
  google_signin_url,
  google_signin_requirement
)

# Save project
project.save

puts "\nProject recreated successfully!"
puts "Added #{files_added} files to the project"
puts "You can now open SnapChef.xcodeproj in Xcode"