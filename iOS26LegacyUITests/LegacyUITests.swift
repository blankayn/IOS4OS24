import XCTest

final class LegacyUITests: XCTestCase {
    override func setUp() { super.setUp(); continueAfterFailure = false }
    func testHomeNotesControlsLockAndSwitcher() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-testing"]; app.launch()
        XCTAssertTrue(app.buttons["app.notes"].waitForExistence(timeout: 5))
        app.buttons["app.notes"].tap()
        XCTAssertTrue(app.textViews["notes.editor"].waitForExistence(timeout: 3))
        app.buttons["shell.controls"].tap()
        XCTAssertTrue(app.otherElements["controls.screen"].exists)
        app.buttons["Done"].tap()
        XCTAssertTrue(app.textViews["notes.editor"].exists)
        app.buttons["shell.home"].tap()
        app.buttons["shell.lock"].tap()
        XCTAssertTrue(app.buttons["lock.enter"].waitForExistence(timeout: 3))
        app.buttons["lock.enter"].tap()
        app.buttons["shell.switcher"].tap()
        XCTAssertTrue(app.buttons["recent.notes"].waitForExistence(timeout: 3))
        app.buttons["recent.notes"].tap()
        XCTAssertTrue(app.textViews["notes.editor"].exists)
    }
    func testSwipeHomePagesAndCalculate() {
        let app = XCUIApplication(); app.launchArguments = ["--ui-testing"]; app.launch()
        let home = app.otherElements["home.screen"]
        home.swipeLeft()
        XCTAssertTrue(app.buttons["app.calculator"].waitForExistence(timeout: 3))
        app.buttons["app.calculator"].tap()
        for key in ["2", "+", "3", "="] { app.buttons["calculator.\(key)"].tap() }
        XCTAssertEqual(app.staticTexts["calculator.display"].label, "5")
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.97))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.65))
        start.press(forDuration: 0.05, thenDragTo: end)
        XCTAssertTrue(app.buttons["app.calculator"].waitForExistence(timeout: 3))
        home.swipeRight()
        XCTAssertTrue(app.buttons["app.notes"].exists)
    }
}
