import XCTest

@MainActor
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

    /// The account screen is built entirely out of List rows, so when a
    /// TapGesture on the TabView started competing with row selection every
    /// control on it went dead while the rest of the app looked fine. Tap two
    /// of those rows for real rather than only asserting they exist.
    func testAccountRowsRespondToTaps() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        let account = app.tabBars.buttons["Cuenta"]
        XCTAssertTrue(account.waitForExistence(timeout: 8))
        account.tap()

        let palette = app.otherElements["palette-picker"]
        XCTAssertTrue(palette.waitForExistence(timeout: 5))
        app.buttons["Catppuccin"].tap()
        XCTAssertTrue(app.buttons["Catppuccin"].isSelected)

        let signIn = app.buttons["Inicia sesión o regístrate"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 5))
        signIn.tap()
        XCTAssertTrue(app.staticTexts["Descubre lo mejor de Loja."].waitForExistence(timeout: 5))
        attachScreenshot(named: "account-auth-sheet")
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

    func testContentHubIsReachableWithoutNetwork() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        let content = app.buttons["Todo lo que pasa en Loja"]
        XCTAssertTrue(content.waitForExistence(timeout: 8))
        content.tap()
        XCTAssertTrue(app.navigationBars["Descubre Loja"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Aún no hay contenido"].waitForExistence(timeout: 5))
        attachScreenshot(named: "content-hub-empty-fixture")
    }

    func testVenueDetailIsReachableWithoutNetwork() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        let venue = app.buttons["Café Loja, local, Centro histórico"]
        XCTAssertTrue(venue.waitForExistence(timeout: 8))
        venue.tap()
        XCTAssertTrue(app.navigationBars["Detalle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Café Loja"].waitForExistence(timeout: 5))
        attachScreenshot(named: "venue-detail-fixture")
    }

    func testContentAndVenueDetailRemainReachableInDarkMode() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTesting-dark"]
        app.launch()

        let content = app.buttons["Todo lo que pasa en Loja"]
        XCTAssertTrue(content.waitForExistence(timeout: 8))
        content.tap()
        XCTAssertTrue(app.navigationBars["Descubre Loja"].waitForExistence(timeout: 5))
        attachScreenshot(named: "content-hub-dark-fixture")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let venue = app.buttons["Café Loja, local, Centro histórico"]
        XCTAssertTrue(venue.waitForExistence(timeout: 5))
        venue.tap()
        XCTAssertTrue(app.navigationBars["Detalle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Café Loja"].waitForExistence(timeout: 5))
        attachScreenshot(named: "venue-detail-dark-fixture")
    }

    func testVenueDetailRemainsReachableWithAccessibilityExtraLargeText() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibility5"
        ]
        app.launch()

        let venue = app.buttons["Café Loja, local, Centro histórico"]
        XCTAssertTrue(venue.waitForExistence(timeout: 8))
        venue.tap()
        XCTAssertTrue(app.navigationBars["Detalle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Café Loja"].waitForExistence(timeout: 5))
        attachScreenshot(named: "venue-detail-accessibility5")
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
        XCTAssertTrue(app.descendants(matching: .any)["explore-map"].waitForExistence(timeout: 8))

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

    func testCoreAccessibilityMatrixAcrossDynamicTypeSizes() {
        let categories: [String?] = [
            nil,
            "UICTContentSizeCategoryXS",
            "UICTContentSizeCategoryAccessibility3",
            "UICTContentSizeCategoryAccessibility5"
        ]

        for category in categories {
            let app = XCUIApplication()
            app.launchArguments = ["-uiTesting"]
            if let category {
                app.launchArguments += ["-UIPreferredContentSizeCategoryName", category]
            }
            app.launch()

            XCTAssertTrue(app.tabBars.buttons["Inicio"].waitForExistence(timeout: 8))
            XCTAssertTrue(app.tabBars.buttons["Explorar"].exists)
            XCTAssertTrue(app.tabBars.buttons["Guardados"].exists)
            XCTAssertTrue(app.tabBars.buttons["Cuenta"].exists)

            let content = app.buttons["Todo lo que pasa en Loja"]
            let venue = app.buttons["Café Loja, local, Centro histórico"]
            XCTAssertTrue(content.exists)
            XCTAssertTrue(venue.exists)
            XCTAssertFalse(content.label.isEmpty)
            XCTAssertFalse(venue.label.isEmpty)
            app.terminate()
        }
    }

    @available(iOS 17.0, *)
    func testMainTabsPassAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Inicio"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Todo lo que pasa en Loja"].exists)
        XCTAssertTrue(app.buttons["Café Loja, local, Centro histórico"].exists)

        try performAccessibilityAuditWithTimeoutRetry(for: app)
    }

    func testTabsRemainReachableInDarkModeWithMotionAndTransparencyReduced() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTesting",
            "-uiTesting-dark",
            "-UIAccessibilityReduceMotionEnabled", "YES",
            "-UIAccessibilityReduceTransparencyEnabled", "YES"
        ]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Inicio"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.tabBars.buttons["Explorar"].exists)
        attachScreenshot(named: "tabs-dark-reduced-motion-transparency")
    }

    func testCreationWizardsAreReachableWithFixtureSession() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTesting-authenticated"]
        app.launch()

        let account = app.tabBars.buttons["Cuenta"]
        XCTAssertTrue(account.waitForExistence(timeout: 8))
        account.tap()
        let accountList = app.collectionViews.firstMatch
        XCTAssertTrue(accountList.waitForExistence(timeout: 5))
        accountList.swipeUp()
        let publish = app.descendants(matching: .any)["creation-hub"]
        XCTAssertTrue(publish.waitForExistence(timeout: 5))
        publish.tap()
        XCTAssertTrue(app.navigationBars["Publicar contenido"].waitForExistence(timeout: 5))

        let wizardCases: [(String, String)] = [
            ("creation-event", "Nuevo evento"),
            ("creation-venue", "Nuevo local"),
            ("creation-post", "Nuevo artículo"),
            ("creation-route", "Nueva ruta")
        ]
        for (entry, title) in wizardCases {
            let link = app.descendants(matching: .any)[entry]
            XCTAssertTrue(link.waitForExistence(timeout: 5), "No se encontró el wizard \(entry)")
            link.tap()
            XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5), "No se abrió \(title)")
            app.navigationBars[title].buttons.element(boundBy: 0).tap()
        }
        attachScreenshot(named: "creation-wizards-fixture")
    }

    func testMyPublicationsStatusViewIsReachableWithFixtureSession() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTesting-authenticated"]
        app.launch()

        let account = app.tabBars.buttons["Cuenta"]
        XCTAssertTrue(account.waitForExistence(timeout: 8))
        account.tap()
        app.collectionViews.firstMatch.swipeUp()
        let publications = app.descendants(matching: .any)["my-publications"]
        XCTAssertTrue(publications.waitForExistence(timeout: 5))
        publications.tap()
        XCTAssertTrue(app.navigationBars["Mis publicaciones"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Aún no has publicado"].waitForExistence(timeout: 5))
    }

    func testExpiredSessionOffersSignInRecovery() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-uiTesting-expired-session"]
        app.launch()

        let alert = app.alerts["Sesión vencida"]
        XCTAssertTrue(alert.waitForExistence(timeout: 8))
        XCTAssertTrue(alert.buttons["Iniciar sesión"].exists)
        alert.buttons["Iniciar sesión"].tap()
        XCTAssertTrue(app.navigationBars["Cuenta"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Bienvenido de vuelta"].waitForExistence(timeout: 5))
        attachScreenshot(named: "expired-session-recovery")
    }

    @MainActor
    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// XCTest occasionally times out while auditing a freshly launched SwiftUI
    /// hierarchy. Restart the fixture app for up to three attempts, and retry
    /// only that framework timeout; real audit findings still fail.
    @MainActor
    private func performAccessibilityAuditWithTimeoutRetry(for app: XCUIApplication) throws {
        for attempt in 1...3 {
            do {
                try app.performAccessibilityAudit()
                return
            } catch let error as NSError
                where error.domain == "com.apple.xcode.xctest.accessibilityAudit" && error.code == -56 {
                guard attempt < 3 else { throw error }
                app.terminate()
                app.launch()
                guard app.tabBars.buttons["Inicio"].waitForExistence(timeout: 8) else {
                    throw error
                }
                guard app.wait(for: .runningForeground, timeout: 5) else {
                    throw error
                }
                RunLoop.current.run(until: Date().addingTimeInterval(0.5))
            }
        }
    }
}
