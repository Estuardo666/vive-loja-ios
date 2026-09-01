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

    func testExploreFiltersSheetIsReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        let explore = app.tabBars.buttons["Explorar"]
        XCTAssertTrue(explore.waitForExistence(timeout: 8))
        explore.tap()
        let filters = app.buttons["Filtros de exploración"]
        XCTAssertTrue(filters.waitForExistence(timeout: 5))
        filters.tap()
        XCTAssertTrue(app.navigationBars["Filtros"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["Abierto ahora"].exists)
        attachScreenshot(named: "explore-filters")
    }

    func testExploreMapAndFilterApplyAreReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        let explore = app.tabBars.buttons["Explorar"]
        XCTAssertTrue(explore.waitForExistence(timeout: 8))
        explore.tap()

        let mapButton = app.buttons["Ver mapa"]
        XCTAssertTrue(mapButton.waitForExistence(timeout: 5))
        mapButton.tap()
        XCTAssertTrue(app.maps.firstMatch.waitForExistence(timeout: 8))

        let filters = app.buttons["Filtros de exploración"]
        XCTAssertTrue(filters.waitForExistence(timeout: 5))
        filters.tap()
        let openNow = app.switches["Abierto ahora"]
        XCTAssertTrue(openNow.waitForExistence(timeout: 5))
        openNow.tap()
        app.buttons["Aplicar"].tap()
        XCTAssertTrue(app.navigationBars["Explorar"].waitForExistence(timeout: 5))
        attachScreenshot(named: "explore-map-filter-applied")
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
