import XCTest
@testable import CycleNavi

final class RideFormatTests: XCTestCase {
    func testUnrepresentableNumbersDoNotTrap() {
        XCTAssertEqual(RideFormat.duration(.greatestFiniteMagnitude), "時間不明")
        XCTAssertEqual(RideFormat.duration(.nan), "時間不明")
        XCTAssertEqual(RideFormat.distance(.nan), "距離不明")
    }
}
