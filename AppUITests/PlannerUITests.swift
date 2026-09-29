import XCTest

final class PlannerUITests: XCTestCase {
    @MainActor func testLargeTextKeepsRouteDetailsReachable() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-route-fixture", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let search = app.buttons["findRoutesButton"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        if !search.isHittable { app.swipeUp() }
        search.tap()
        let details = app.buttons["routeDetailsButton"]
        XCTAssertTrue(details.waitForExistence(timeout: 10))
        for _ in 0..<12 where !details.isHittable { app.scrollViews["plannerScroll"].swipeUp() }
        XCTAssertTrue(details.isHittable)
        details.tap()
        XCTAssertTrue(app.buttons["音声停止"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["閉じる"].tap()
    }
    @MainActor func testFixtureRouteAndSpeechControls() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-test-route-fixture"]
        app.launch()
        XCTAssertTrue(app.buttons["findRoutesButton"].waitForExistence(timeout: 10))
        app.buttons["findRoutesButton"].tap()
        let detail = app.buttons["routeDetailsButton"]
        XCTAssertTrue(detail.waitForExistence(timeout: 10))
        if !detail.isHittable { app.swipeUp() }
        let routeImage = XCTAttachment(screenshot: app.screenshot())
        routeImage.lifetime = .keepAlways
        add(routeImage)
        detail.tap()
        let speak = app.buttons["speakStep0"]
        XCTAssertTrue(speak.waitForExistence(timeout: 5))
        speak.tap()
        app.buttons["音声停止"].tap()
        app.buttons["閉じる"].tap()
        app.swipeDown()
        app.buttons["preferencesButton"].tap()
        app.buttons["ロード"].tap()
        app.buttons["完了"].tap()
        XCTAssertFalse(app.buttons["routeDetailsButton"].exists)
    }
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
