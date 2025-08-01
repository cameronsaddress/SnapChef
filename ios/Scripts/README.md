# SnapChef Xcode Project Scripts

This directory contains utility scripts for managing the SnapChef Xcode project.

## add-to-xcode

A convenient wrapper for adding Swift files to the Xcode project safely.

### Installation

First, ensure you have the required Ruby gem installed:
```bash
gem install xcodeproj
```

### Usage

Basic usage:
```bash
./Scripts/add-to-xcode <group_path> <files...>
```

### Examples

Add a single file to the Social features:
```bash
./Scripts/add-to-xcode SnapChef/Features/Social ActivityFeedView.swift
```

Add multiple files to Authentication:
```bash
./Scripts/add-to-xcode SnapChef/Features/Authentication LoginView.swift SignupView.swift ResetPasswordView.swift
```

Create files if they don't exist:
```bash
./Scripts/add-to-xcode -c SnapChef/Features/Profile SettingsView.swift
```

List available targets:
```bash
./Scripts/add-to-xcode -l
```

List groups in a specific path:
```bash
./Scripts/add-to-xcode -g SnapChef/Features
```

### Options

- `-t, --target NAME` - Specify target name (default: SnapChef)
- `-p, --project PATH` - Specify project path (default: ./SnapChef.xcodeproj)
- `-l, --list-targets` - List all available targets
- `-g, --list-groups [PATH]` - List groups in project or at specific path
- `-c, --create` - Create files if they don't exist on disk
- `-h, --help` - Show help message

## add_files_to_xcode.rb

The underlying Ruby script that safely modifies the Xcode project file.

### Direct Usage

```bash
ruby Scripts/add_files_to_xcode.rb <project_path> <target_name> <group_path> <files...>
```

### Features

1. **Safe File Addition**
   - Checks for existing files before adding
   - Validates target existence
   - Maintains proper group structure
   - Handles different file types appropriately

2. **Error Prevention**
   - Creates automatic backups before modifications
   - Validates project integrity
   - Provides clear error messages

3. **Build Phase Management**
   - Swift/Objective-C files → Source Build Phase
   - Storyboards/XIBs/Assets → Resources Build Phase
   - Headers → No build phase (for Swift projects)

### Technical Details

The script uses the `xcodeproj` gem by CocoaPods to:
- Parse the .pbxproj file structure
- Create proper file references with unique UUIDs
- Add files to appropriate build phases
- Maintain project integrity

### Troubleshooting

**"Target not found" error:**
- Run `./Scripts/add-to-xcode -l` to see available targets
- Ensure you're using the correct target name

**"Group not found" error:**
- Run `./Scripts/add-to-xcode -g` to see the group structure
- Create parent groups if needed

**"File already exists" warning:**
- This is normal if the file is already in the project
- The script will still ensure it's added to the target

**Permission errors:**
- Ensure the scripts are executable: `chmod +x Scripts/add-to-xcode`
- You may need to use `sudo gem install xcodeproj` if gem install fails

## Best Practices

1. **Always commit before making changes** - While the script creates backups, it's best to have version control as well

2. **Use proper group paths** - Match the folder structure in Xcode to your file system

3. **Add files in batches** - You can add multiple files at once to the same group

4. **Verify in Xcode** - After adding files, open Xcode to ensure everything looks correct

5. **Run a build** - Always build the project after adding files to catch any issues early

## Integration with AI Assistants

When working with AI assistants like Claude, you can use these scripts to properly add generated files:

```bash
# After AI creates a new view file
./Scripts/add-to-xcode SnapChef/Features/NewFeature GeneratedView.swift

# After AI creates multiple related files
./Scripts/add-to-xcode SnapChef/Features/API APIClient.swift APIModels.swift APIEndpoints.swift
```

This ensures files are properly integrated into the Xcode project without manual intervention or risk of corruption.