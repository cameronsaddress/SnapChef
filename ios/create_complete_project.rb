#!/usr/bin/env ruby

require 'xcodeproj'

puts "Creating complete SnapChef Xcode project..."

# Remove any existing project
system("rm -rf SnapChef.xcodeproj") if File.exist?('SnapChef.xcodeproj')

# Create new project
project = Xcodeproj::Project.new('SnapChef.xcodeproj')

# Create the main target
target = project.new_target(:application, 'SnapChef', :ios, '16.0')
target.product_name = 'SnapChef'

# Configure target settings
target.build_configurations.each do |config|
  config.build_settings.merge!({
    'PRODUCT_BUNDLE_IDENTIFIER' => 'com.snapchef.app',
    'DEVELOPMENT_TEAM' => '',
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
    'INFOPLIST_KEY_NSCameraUsageDescription' => 'This app needs camera access to take photos of your food.',
    'INFOPLIST_KEY_UIApplicationSceneManifest_Generation' => 'YES',
    'INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents' => 'YES',
    'INFOPLIST_KEY_UILaunchScreen_Generation' => 'YES',
    'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad' => 'UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight',
    'INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone' => 'UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight',
    'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/Frameworks',
    'MARKETING_VERSION' => '1.0',
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'SWIFT_EMIT_LOC_STRINGS' => 'YES'
  })
end

puts "Creating group structure..."

# Create main group structure
snapchef_group = project.main_group.new_group('SnapChef')

# App group
app_group = snapchef_group.new_group('App')

# Core group and subgroups
core_group = snapchef_group.new_group('Core')
models_group = core_group.new_group('Models')
viewmodels_group = core_group.new_group('ViewModels')
services_group = core_group.new_group('Services')
networking_group = core_group.new_group('Networking')
utilities_group = core_group.new_group('Utilities')

# Features group and subgroups
features_group = snapchef_group.new_group('Features')
home_group = features_group.new_group('Home')
camera_group = features_group.new_group('Camera')
recipes_group = features_group.new_group('Recipes')
profile_group = features_group.new_group('Profile')
share_group = features_group.new_group('Share')
auth_group = features_group.new_group('Authentication')
sharing_group = features_group.new_group('Sharing')

# Design group and subgroups
design_group = snapchef_group.new_group('Design')
components_group = design_group.new_group('Components')

# Resources
resources_group = snapchef_group.new_group('Resources')
preview_group = snapchef_group.new_group('Preview Content')

puts "Adding files to project..."

# Define all files to add with their groups
files_to_add = [
  # App files
  { path: 'SnapChef/App/SnapChefApp.swift', group: app_group, build_phase: 'source' },
  { path: 'SnapChef/App/ContentView.swift', group: app_group, build_phase: 'source' },
  
  # Core - Models
  { path: 'SnapChef/Core/Models/Recipe.swift', group: models_group, build_phase: 'source' },
  { path: 'SnapChef/Core/Models/User.swift', group: models_group, build_phase: 'source' },
  
  # Core - ViewModels
  { path: 'SnapChef/Core/ViewModels/AppState.swift', group: viewmodels_group, build_phase: 'source' },
  
  # Core - Services
  { path: 'SnapChef/Core/Services/AuthenticationManager.swift', group: services_group, build_phase: 'source' },
  { path: 'SnapChef/Core/Services/DeviceManager.swift', group: services_group, build_phase: 'source' },
  
  # Core - Networking
  { path: 'SnapChef/Core/Networking/NetworkManager.swift', group: networking_group, build_phase: 'source' },
  
  # Core - Utilities
  { path: 'SnapChef/Core/Utilities/HapticManager.swift', group: utilities_group, build_phase: 'source' },
  { path: 'SnapChef/Core/Utilities/MockDataProvider.swift', group: utilities_group, build_phase: 'source' },
  
  # Features - Home
  { path: 'SnapChef/EnhancedHomeView.swift', group: home_group, build_phase: 'source' },
  
  # Features - Camera
  { path: 'SnapChef/Features/Camera/CameraModel.swift', group: camera_group, build_phase: 'source' },
  { path: 'SnapChef/Features/Camera/CameraView.swift', group: camera_group, build_phase: 'source' },
  { path: 'SnapChef/Features/Camera/HomeView.swift', group: camera_group, build_phase: 'source' },
  { path: 'SnapChef/Features/Camera/EnhancedCameraView.swift', group: camera_group, build_phase: 'source' },
  
  # Features - Recipes
  { path: 'SnapChef/Features/Recipes/RecipeResultsView.swift', group: recipes_group, build_phase: 'source' },
  { path: 'SnapChef/Features/Recipes/RecipesView.swift', group: recipes_group, build_phase: 'source' },
  { path: 'SnapChef/Features/Recipes/EnhancedRecipesView.swift', group: recipes_group, build_phase: 'source' },
  { path: 'SnapChef/Features/Recipes/EnhancedRecipeResultsView.swift', group: recipes_group, build_phase: 'source' },
  
  # Features - Profile
  { path: 'SnapChef/Features/Profile/ProfileView.swift', group: profile_group, build_phase: 'source' },
  { path: 'SnapChef/Features/Profile/EnhancedProfileView.swift', group: profile_group, build_phase: 'source' },
  
  # Features - Share
  { path: 'SnapChef/Features/Share/EnhancedShareSheet.swift', group: share_group, build_phase: 'source' },
  
  # Features - Authentication
  { path: 'SnapChef/Features/Authentication/OnboardingView.swift', group: auth_group, build_phase: 'source' },
  { path: 'SnapChef/Features/Authentication/SubscriptionView.swift', group: auth_group, build_phase: 'source' },
  
  # Features - Sharing
  { path: 'SnapChef/Features/Sharing/PrintView.swift', group: sharing_group, build_phase: 'source' },
  { path: 'SnapChef/Features/Sharing/ShareSheet.swift', group: sharing_group, build_phase: 'source' },
  
  # Design
  { path: 'SnapChef/Design/MagicalBackground.swift', group: design_group, build_phase: 'source' },
  { path: 'SnapChef/Design/GlassmorphicComponents.swift', group: design_group, build_phase: 'source' },
  { path: 'SnapChef/Design/MorphingTabBar.swift', group: design_group, build_phase: 'source' },
  { path: 'SnapChef/Design/MagicalTransitions.swift', group: design_group, build_phase: 'source' },
  
  # Design - Components
  { path: 'SnapChef/Design/Components/FloatingFoodAnimation.swift', group: components_group, build_phase: 'source' },
  { path: 'SnapChef/Design/Components/GradientBackground.swift', group: components_group, build_phase: 'source' },
  
  # Resources
  { path: 'SnapChef/Design/Assets.xcassets', group: design_group, build_phase: 'resources' },
  { path: 'SnapChef/SnapChef.entitlements', group: snapchef_group, build_phase: 'none' },
  { path: 'SnapChef/Info.plist', group: snapchef_group, build_phase: 'none' },
  
  # Preview Content
  { path: 'SnapChef/Preview Content/Preview Assets.xcassets', group: preview_group, build_phase: 'resources' }
]

# Add files to project
files_added = 0
files_missing = []

files_to_add.each do |file_info|
  file_path = file_info[:path]
  group = file_info[:group]
  build_phase = file_info[:build_phase]
  
  if File.exist?(file_path)
    # Add file reference
    file_ref = group.new_reference(file_path)
    
    # Add to appropriate build phase
    case build_phase
    when 'source'
      target.source_build_phase.add_file_reference(file_ref)
    when 'resources'
      target.resources_build_phase.add_file_reference(file_ref)
    # 'none' means don't add to build phase
    end
    
    files_added += 1
    puts "  ✓ Added: #{file_path}"
  else
    files_missing << file_path
    puts "  ✗ Missing: #{file_path}"
  end
end

# Add Swift Package Manager dependencies
puts "\nConfiguring package dependencies..."

# Create Package.resolved file structure for GoogleSignIn
package_resolved = {
  "pins" => [
    {
      "identity" => "appauth-ios",
      "kind" => "remoteSourceControl",
      "location" => "https://github.com/openid/AppAuth-iOS.git",
      "state" => {
        "revision" => "71cde449f13d453227e687458144bde372d30fc7",
        "version" => "1.7.6"
      }
    },
    {
      "identity" => "googlesignin-ios",
      "kind" => "remoteSourceControl", 
      "location" => "https://github.com/google/GoogleSignIn-iOS",
      "state" => {
        "revision" => "a7965d134c5d3567026c523de5909d6d8c94c5d9",
        "version" => "7.1.0"
      }
    },
    {
      "identity" => "gtmappauth",
      "kind" => "remoteSourceControl",
      "location" => "https://github.com/google/GTMAppAuth.git", 
      "state" => {
        "revision" => "5d7d66f647400952b1758b230e019b07c0b4b22a",
        "version" => "4.1.1"
      }
    },
    {
      "identity" => "gtm-session-fetcher",
      "kind" => "remoteSourceControl",
      "location" => "https://github.com/google/gtm-session-fetcher.git",
      "state" => {
        "revision" => "a2ab612cb980066ee56d90d60d8462992c07f24b",
        "version" => "3.5.0"
      }
    }
  ],
  "version" => 2
}

# Create the project's Package.swift equivalent
project_remote_packages = [
  {
    'repositoryURL' => 'https://github.com/google/GoogleSignIn-iOS',
    'requirement' => { 'kind' => 'upToNextMajorVersion', 'minimumVersion' => '7.1.0' }
  }
]

# Add package product dependencies to target
begin
  # This creates the package dependency structure
  remote_package = project.new_swift_package_remote('https://github.com/google/GoogleSignIn-iOS')
  remote_package.requirement = { 'kind' => 'upToNextMajorVersion', 'minimumVersion' => '7.1.0' }
  
  # Add product dependency
  product_dep = target.new_swift_package_product_dependency('GoogleSignIn', remote_package)
  target.package_product_dependencies << product_dep
  
  puts "  ✓ Added GoogleSignIn package dependency"
rescue => e
  puts "  ⚠ Package dependency setup may need manual configuration in Xcode"
  puts "    Add: https://github.com/google/GoogleSignIn-iOS"
end

# Save the project
project.save

puts "\n" + "="*60
puts "PROJECT CREATION COMPLETE!"
puts "="*60
puts "Files added: #{files_added}"
puts "Files missing: #{files_missing.count}"

if files_missing.any?
  puts "\nMissing files:"
  files_missing.each { |f| puts "  - #{f}" }
end

puts "\nNext steps:"
puts "1. Open SnapChef.xcodeproj in Xcode"
puts "2. Add package dependency manually if needed:"
puts "   File > Add Package Dependencies"
puts "   https://github.com/google/GoogleSignIn-iOS"
puts "3. Build the project (⌘B)"
puts "\nYour beautiful enhanced app is ready to build! 🎉"