import XCTest

final class PlannerUITests: XCTestCase {
    @MainActor func testSearchAndPreferencesAreReachable() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["destinationButton"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["findRoutesButton"].isEnabled)
        app.buttons["destinationButton"].tap()
        XCTAssertTrue(app.textFields["placeSearchField"].waitForExistence(timeout: 5))
        app.buttons["閉じる"].tap()
        XCTAssertTrue(app.buttons["originButton"].exists)
        app.buttons["preferencesButton"].tap()
        XCTAssertTrue(app.staticTexts["自転車と道の好み"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.sliders["detourSlider"].exists)
        XCTAssertTrue(app.switches["pavedOnlyToggle"].exists)
        app.buttons["完了"].tap()
        XCTAssertTrue(app.buttons["destinationButton"].exists)
    }
}
