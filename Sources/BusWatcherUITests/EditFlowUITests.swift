import XCTest

@MainActor
final class EditFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-resetDefaults"]
        app.launch()
        return app
    }

    func test_editButton_opensSheet() {
        let app = launchApp()
        let editButton = app.buttons["editStopsButton"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        editButton.tap()
        XCTAssertTrue(app.navigationBars["Edit Stops"].waitForExistence(timeout: 2))
    }

    func test_delete_removesRow() {
        let app = launchApp()
        app.buttons["editStopsButton"].tap()

        // Wait for the sheet.
        XCTAssertTrue(app.navigationBars["Edit Stops"].waitForExistence(timeout: 3))

        // Swipe-delete the first stop (default: 11A / St Mary's Rd).
        let firstCell = app.collectionViews.cells.element(boundBy: 0)
        if !firstCell.waitForExistence(timeout: 2) {
            // Fall back: some SwiftUI Lists use tables not collection views.
            let fallback = app.tables.cells.element(boundBy: 0)
            XCTAssertTrue(fallback.waitForExistence(timeout: 2))
            fallback.swipeLeft()
        } else {
            firstCell.swipeLeft()
        }
        app.buttons["Delete"].firstMatch.tap()

        app.buttons["editorCloseButton"].tap()

        // Back on main view: St Mary's Rd card should be gone.
        XCTAssertFalse(app.staticTexts["St Mary's Rd"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["York St"].exists)
    }

    func test_reorder_rowsRemainAfterMove() {
        let app = launchApp()
        app.buttons["editStopsButton"].tap()

        XCTAssertTrue(app.navigationBars["Edit Stops"].waitForExistence(timeout: 3))

        app.navigationBars["Edit Stops"].buttons["Edit"].tap()

        let allCells = app.collectionViews.cells.count > 0 ? app.collectionViews.cells : app.tables.cells
        XCTAssertGreaterThanOrEqual(allCells.count, 4)

        let firstRow = allCells.element(boundBy: 0)
        let lastRow = allCells.element(boundBy: 3)

        // Long-press on trailing edge and drag below last row.
        let start = firstRow.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        let end = lastRow.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 1.5))
        start.press(forDuration: 0.8, thenDragTo: end)

        app.buttons["editorCloseButton"].tap()

        // All 4 stops still visible.
        XCTAssertTrue(app.staticTexts["St Mary's Rd"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["York St"].exists)
        XCTAssertTrue(app.staticTexts["Station St"].exists)
        XCTAssertTrue(app.staticTexts["Vicarage Rd"].exists)
    }
}
