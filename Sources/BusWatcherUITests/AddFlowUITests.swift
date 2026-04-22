import XCTest

/// Lightweight smoke-tests for the Add Stop flow. These only exercise the parts that don't
/// require network mocking (opening the Add view, typing a search query that hits the bundled
/// stops.txt index). Full end-to-end add flow needs a mock TfWMService injected into the app —
/// see the follow-up task below.
///
/// TODO: to extend to end-to-end, introduce a protocol-backed TfWMService and swap in a fixture
/// implementation when `-uiTesting` is present, then drive the full add flow including the
/// Configure screen (which fetches stop detail).
final class AddFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-resetDefaults"]
        app.launch()
        return app
    }

    func test_addLink_navigatesToAddStopView() {
        let app = launchApp()
        app.buttons["editStopsButton"].tap()
        let addLink = app.buttons["addStopLink"]
        XCTAssertTrue(addLink.waitForExistence(timeout: 2))
        addLink.tap()
        XCTAssertTrue(app.navigationBars["Add Stop"].waitForExistence(timeout: 2))
    }

    func test_searchField_populatesResults() {
        let app = launchApp()
        app.buttons["editStopsButton"].tap()
        app.buttons["addStopLink"].tap()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        searchField.tap()
        searchField.typeText("York St")

        // Wait for debounce + index load. A real match from bundled stops.txt should appear.
        let anyResult = app.staticTexts["York St"]
        XCTAssertTrue(anyResult.waitForExistence(timeout: 6))
    }
}
