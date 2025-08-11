#\!/bin/bash

# Find the Debug configuration line and add Swift 6 concurrency settings
sed -i '' '/D8C8648598E80D50933E1963.*Debug.*{/,/};/ {
    /SWIFT_VERSION = 6.0;/a\
				SWIFT_STRICT_CONCURRENCY = complete;\
				SWIFT_UPCOMING_FEATURE_CONCISE_MAGIC_FILE = YES;\
				SWIFT_UPCOMING_FEATURE_FORWARD_TRAILING_CLOSURES = YES;\
				SWIFT_UPCOMING_FEATURE_IMPLICIT_OPEN_EXISTENTIALS = YES;\
				SWIFT_UPCOMING_FEATURE_IMPORT_OBJC_FORWARD_DECLS = YES;
}' SnapChef.xcodeproj/project.pbxproj

# Find the Release configuration and add the same settings
sed -i '' '/506E7A0E369F7C89CA737788.*Release.*{/,/};/ {
    /SWIFT_VERSION = 6.0;/a\
				SWIFT_STRICT_CONCURRENCY = complete;\
				SWIFT_UPCOMING_FEATURE_CONCISE_MAGIC_FILE = YES;\
				SWIFT_UPCOMING_FEATURE_FORWARD_TRAILING_CLOSURES = YES;\
				SWIFT_UPCOMING_FEATURE_IMPLICIT_OPEN_EXISTENTIALS = YES;\
				SWIFT_UPCOMING_FEATURE_IMPORT_OBJC_FORWARD_DECLS = YES;
}' SnapChef.xcodeproj/project.pbxproj

echo "Swift 6 settings added to project.pbxproj"
