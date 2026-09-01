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
        attachScreenshot(named: "tabs-default")
    }

    func testExploreTabShowsSearchControl() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        let explore = app.tabBars.buttons["Explorar"]
        XCTAssertTrue(explore.waitForExistence(timeout: 8))
        explore.tap()
        XCTAssertTrue(app.textFields["explore-search"].waitForExistence(timeout: 5))
        attachScreenshot(named: "explore-default")
    }

    func testTabsRemainReachableWithAccessibilityDynamicType() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibility3"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Inicio"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.tabBars.buttons["Cuenta"].exists)
        attachScreenshot(named: "tabs-dynamic-type-accessibility3")
    }

    func testTabsRemainReachableInDarkModeWithMotionAndTransparencyReduced() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-AppleInterfaceStyle", "Dark",
            "-UIAccessibilityReduceMotionEnabled", "YES",
            "-UIAccessibilityReduceTransparencyEnabled", "YES"
        ]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Inicio"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.tabBars.buttons["Explorar"].exists)
        attachScreenshot(named: "tabs-dark-reduced-motion-transparency")
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
