import XCTest

/// Explicitly opt in with the CycleNaviLive scheme.
final class LiveMapUITests: XCTestCase {
    @MainActor func testTokyoCyclingRoute() throws { try verifyRoute(origin: "吉祥寺駅", destination: "立川駅") }
    @MainActor func testKanagawaCyclingRoute() throws { try verifyRoute(origin: "武蔵小杉駅", destination: "登戸駅") }

    @MainActor private func verifyRoute(origin: String, destination: String) throws {
        guard let endpoint = ProcessInfo.processInfo.environment["CYCLENAVI_VALHALLA_ROUTE_URL"],
              !endpoint.isEmpty, !endpoint.contains("$(") else {
            throw XCTSkip("Valhalla接続先未設定：実通信は未検証")
        }
        let app = XCUIApplication()
        continueAfterFailure = false
        app.launchEnvironment["CYCLENAVI_VALHALLA_ROUTE_URL"] = endpoint
        app.launch()
        XCTAssertTrue(app.buttons["originButton"].waitForExistence(timeout: 15))
        for (button, query) in [("originButton", origin), ("destinationButton", destination)] {
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
        XCTAssertTrue(details.waitForExistence(timeout: 70), app.debugDescription)
        if !details.isHittable { app.swipeUp() }
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.lifetime = .keepAlways
        add(capture)
        details.tap()
        XCTAssertTrue(app.staticTexts["案内文をタップすると読み上げます。現在地に応じた自動ナビはまだ接続していません。"].waitForExistence(timeout: 5))
        let instruction = app.buttons["speakStep0"]
        XCTAssertTrue(instruction.waitForExistence(timeout: 5))
        instruction.tap()
        app.buttons["音声停止"].tap()
    }
}
