import XCTest

/// Explicitly opt in with the CycleNaviLive scheme.
final class LiveMapUITests: XCTestCase {
    @MainActor func testLiveCyclingRoute() throws {
        let app = XCUIApplication()
        continueAfterFailure = false
        app.launch()
        XCTAssertTrue(app.buttons["originButton"].waitForExistence(timeout: 15))
        for (button, query) in [("originButton", "吉祥寺駅"), ("destinationButton", "立川駅")] {
            app.buttons[button].tap()
            let field = app.textFields["placeSearchField"]
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            field.typeText(query)
            let result = app.cells.firstMatch.buttons.firstMatch
            XCTAssertTrue(result.waitForExistence(timeout: 30), app.debugDescription)
            result.tap()
        }
        let search = app.buttons["findRoutesButton"]
        if !search.isHittable { app.swipeUp() }
        search.tap()
        let details = app.buttons["routeDetailsButton"]
        XCTAssertTrue(details.waitForExistence(timeout: 45), app.debugDescription)
        if !details.isHittable { app.swipeUp() }
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.lifetime = .keepAlways
        add(capture)
        details.tap()
        XCTAssertTrue(app.staticTexts["案内文をタップすると読み上げます。現在地に応じた自動ナビはまだ接続していません。"].waitForExistence(timeout: 5))
    }
}
