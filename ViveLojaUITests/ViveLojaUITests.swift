import XCTest

final class ViveLojaUITests: XCTestCase {
    func testMainTabsAreReachableWithoutNetwork() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Inicio"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.tabBars.buttons["Explorar"].exists)
        XCTAssertTrue(app.tabBars.buttons["Guardados"].exists)
        XCTAssertTrue(app.tabBars.buttons["Cuenta"].exists)
    }

    func testExploreTabShowsSearchControl() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        let explore = app.tabBars.buttons["Explorar"]
        XCTAssertTrue(explore.waitForExistence(timeout: 8))
        explore.tap()
        XCTAssertTrue(app.textFields["explore-search"].waitForExistence(timeout: 5))
    }

    func testTabsRemainReachableWithAccessibilityDynamicType() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibility3"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Inicio"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.tabBars.buttons["Cuenta"].exists)
    }
}
