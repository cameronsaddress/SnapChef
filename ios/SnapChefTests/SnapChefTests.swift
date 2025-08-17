import XCTest
@testable import SnapChef

final class SnapChefTests: XCTestCase {
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    // MARK: - Basic Test Setup Verification
    
    func testTestEnvironmentSetup() throws {
        // This test ensures our test environment is properly configured
        XCTAssertTrue(true, "Test environment is working")
    }
    
    func testAppBundleExists() throws {
        let bundle = Bundle(for: type(of: self))
        XCTAssertNotNil(bundle, "Test bundle should exist")
    }
}