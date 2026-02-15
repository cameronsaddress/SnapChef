import XCTest

final class SnapChefUISmokeTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments += ["-uiTesting"]

        addUIInterruptionMonitor(withDescription: "System alerts") { alert in
            for label in ["Not Now", "Cancel", "Don't Allow", "OK", "Close"] {
                if alert.buttons[label].exists {
                    alert.buttons[label].tap()
                    return true
                }
            }
            return false
        }

        app.launch()
        // Trigger the interruption monitor if an alert is present.
        app.tap()
    }

    func testSmoke_NavigateTabsAndDiscoverChefs_DoesNotCrash() throws {
        // Home tab should always be reachable.
        XCTAssertTrue(app.buttons["tab_home"].waitForExistence(timeout: 10))
        app.buttons["tab_home"].tap()

        // Feed tab should be reachable.
        XCTAssertTrue(app.buttons["tab_feed"].waitForExistence(timeout: 10))
        app.buttons["tab_feed"].tap()

        // Guest overlay still allows browsing chefs.
        if app.buttons["cta_browse_chefs"].waitForExistence(timeout: 5) {
            app.buttons["cta_browse_chefs"].tap()
        } else if app.buttons["cta_discover_chefs"].waitForExistence(timeout: 5) {
            app.buttons["cta_discover_chefs"].tap()
        }

        XCTAssertTrue(app.staticTexts["Discover Chefs"].waitForExistence(timeout: 10))

        // Tap the first chef card if present (demo or CloudKit). Dismiss the sheet.
        let firstChefCard = app.buttons["discover_user_card"].firstMatch
        if firstChefCard.waitForExistence(timeout: 5) {
            firstChefCard.tap()
            // Allow sheet content to appear; then dismiss via explicit Done button when present.
            sleep(1)
            if app.buttons["chef_profile_done"].waitForExistence(timeout: 3) {
                app.buttons["chef_profile_done"].tap()
            } else {
                app.swipeDown()
            }
        }

        // Dismiss the Discover Chefs sheet so the main tab bar becomes hittable again.
        if app.buttons["discover_chefs_close"].waitForExistence(timeout: 5) {
            app.buttons["discover_chefs_close"].tap()
        } else {
            app.swipeDown()
        }

        // Recipes tab should not crash.
        XCTAssertTrue(app.buttons["tab_recipes"].waitForExistence(timeout: 10))
        app.buttons["tab_recipes"].tap()

        // Profile tab should not crash (guest profile shown when unauthenticated).
        XCTAssertTrue(app.buttons["tab_profile"].waitForExistence(timeout: 10))
        app.buttons["tab_profile"].tap()
        XCTAssertTrue(app.buttons["profile_display_name"].waitForExistence(timeout: 10))
    }
}
