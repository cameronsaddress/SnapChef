# SnapChef Unit Test Plan

## Overview
Comprehensive unit test suite for SnapChef iOS app covering critical functionality including recipe generation, authentication, subscriptions, error handling, and core app state management.

## Test Coverage Goals
- **Target Coverage**: 80%+ code coverage
- **Critical Paths**: 100% coverage for recipe generation, authentication, and error handling
- **Performance**: All tests should complete in under 30 seconds

## Test Categories

### 1. Core Functionality Tests

#### AppState Tests (`AppStateTests.swift`)
- ✅ App initialization and onboarding
- ✅ Recipe management (add, save, favorite, delete)
- ✅ Counter tracking (snaps, shares, likes)
- ✅ Error handling and clearing
- ✅ Progressive premium integration
- ✅ Anonymous action tracking

#### Recipe Model Tests (`RecipeTests.swift`)
- ✅ Recipe model initialization and validation
- ✅ Difficulty enum properties and colors
- ✅ Ingredient model with optional fields
- ✅ Nutrition model validation
- ✅ Dietary info tracking
- ✅ Codable conformance for persistence
- ✅ Sendable conformance for Swift 6

### 2. Networking and API Tests

#### SnapChefAPIManager Tests (`SnapChefAPIManagerTests.swift`)
- ✅ Singleton pattern validation
- ✅ Image resizing and compression
- ✅ API response model validation
- ✅ Recipe conversion from API to app models
- ✅ Error handling for different HTTP status codes
- ✅ Multipart form data creation
- ✅ Performance testing for image processing

### 3. Authentication Tests

#### AuthenticationManager Tests (`AuthenticationManagerTests.swift`)
- ✅ Initial authentication state
- ✅ Authentication requirements for features
- ✅ User management and profile updates
- ✅ Sign-in provider support (Apple, Google, Facebook)
- ✅ Error handling for authentication failures
- ✅ Auth data model validation

### 4. Subscription and Premium Tests

#### SubscriptionManager Tests (`SubscriptionManagerTests.swift`)
- ✅ Subscription status management
- ✅ Premium feature access control
- ✅ Product ID validation
- ✅ Premium challenge management
- ✅ Reward multiplier calculations
- ✅ Daily limits and usage tracking
- ✅ Legacy method compatibility

### 5. Error Handling Tests

#### ErrorHandler Tests (`ErrorHandlerTests.swift`)
- ✅ Comprehensive error type validation
- ✅ User-friendly error messages
- ✅ Error recovery strategies
- ✅ CloudKit error conversion
- ✅ Global error handler functionality
- ✅ Retry mechanism with exponential backoff
- ✅ Error analytics and logging

### 6. Integration Tests

#### Recipe Generation Integration (`RecipeGenerationIntegrationTests.swift`)
- ✅ Complete recipe generation flow
- ✅ Dietary restriction handling
- ✅ Progressive premium integration
- ✅ Error handling integration
- ✅ API to app model conversion
- ✅ Recipe persistence and management
- ✅ Multi-recipe generation scenarios

## Test Execution Strategy

### Local Development
```bash
# Run all tests
cmd+U in Xcode

# Run specific test class
xcodebuild test -scheme SnapChef -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:SnapChefTests/AppStateTests

# Run with coverage
xcodebuild test -scheme SnapChef -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -enableCodeCoverage YES
```

### Continuous Integration
- Tests run on every pull request
- Coverage reports generated automatically
- Performance regression detection
- Test failure notifications

## Mock Data Strategy

### Mock Objects Used
- **Mock Images**: Generated programmatically for image processing tests
- **Mock Recipes**: Standardized test recipes with known properties
- **Mock API Responses**: Predefined API response structures
- **Mock User Data**: Test user profiles and authentication states

### Test Data Isolation
- UserDefaults cleared before each test
- Singleton instances reset where necessary
- File system cleanup after persistence tests
- Network mocking for API tests (future enhancement)

## Performance Testing

### Current Performance Tests
- Image resizing performance (large images)
- Recipe conversion performance (complex recipes)
- AppState management under load

### Performance Targets
- Image resize: <100ms for 4K images
- Recipe conversion: <10ms per recipe
- App state operations: <1ms each

## Test Environment Setup

### Requirements
- iOS 17.0+ simulator
- iPhone 16 Pro simulator (recommended)
- Xcode 15.0+
- Swift 6 compatibility

### Configuration
- Tests run in isolated environment
- UserDefaults and file system cleaned between tests
- Network requests mocked or disabled
- Analytics and crash reporting disabled

## Future Enhancements

### Planned Test Additions
1. **UI Tests**: SwiftUI component testing
2. **Network Mocking**: URLSession mocking for API tests
3. **CloudKit Mocking**: CloudKit operation testing
4. **Camera Testing**: AVCaptureSession mocking
5. **Push Notification Testing**: UNUserNotificationCenter mocking

### Test Quality Improvements
1. **Snapshot Testing**: UI component visual regression testing
2. **Property-Based Testing**: Fuzz testing for edge cases
3. **Load Testing**: Stress testing with large datasets
4. **Security Testing**: Input validation and sanitization tests

## Debugging Failed Tests

### Common Issues and Solutions

1. **Test Timeout**
   - Increase timeout values for async operations
   - Check for retain cycles in test setup

2. **Simulator Issues**
   - Reset simulator between test runs
   - Use iPhone 16 Pro simulator for consistency

3. **UserDefaults Conflicts**
   - Ensure proper cleanup in tearDown methods
   - Use unique keys for test data

4. **File System Issues**
   - Clean up temporary files in tearDown
   - Use proper file permissions

## Coverage Reports

### Current Coverage Targets
- Core Models: 95%+
- API Manager: 90%+
- App State: 95%+
- Authentication: 85%+
- Error Handling: 90%+
- Integration Flows: 80%+

### Excluded from Coverage
- SwiftUI view code (tested via UI tests)
- Third-party SDK integration
- Debug-only code paths
- Crashlytics and analytics code

## Test Maintenance

### Regular Tasks
- Update tests when models change
- Add tests for new features
- Remove tests for deprecated features
- Update mock data to match API changes
- Review and update performance benchmarks

### Test Review Process
- All new features must include unit tests
- Test coverage must not decrease with new code
- Performance tests must pass on CI
- Integration tests must cover happy path and error scenarios

## Running Tests

### Xcode
1. Open SnapChef.xcodeproj
2. Select SnapChefTests scheme
3. Press Cmd+U to run all tests
4. View results in Test Navigator

### Command Line
```bash
# Run all tests
xcodebuild test -project SnapChef.xcodeproj -scheme SnapChef -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Run with coverage
xcodebuild test -project SnapChef.xcodeproj -scheme SnapChef -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -enableCodeCoverage YES

# Run specific test class
xcodebuild test -project SnapChef.xcodeproj -scheme SnapChef -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:SnapChefTests/AppStateTests

# Generate coverage report
xcrun xccov view --report --only-targets DerivedData/SnapChef/Logs/Test/*.xcresult
```

## Success Criteria
- All tests pass on CI
- Coverage targets met
- Performance benchmarks passed
- No test flakiness
- Tests complete in under 30 seconds