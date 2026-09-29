import XCTest
import CoreLocation
@testable import CycleNavi

final class LocationServiceTests: XCTestCase {
    @MainActor func testCanceledLocationCannotPublishLateResult() {
        let service = LocationService()
        service.cancel()
        service.receive(CLLocation(coordinate: CLLocationCoordinate2D(latitude: 35.7, longitude: 139.5),
                                   altitude: 0, horizontalAccuracy: 5, verticalAccuracy: 5,
                                   timestamp: Date()))
        XCTAssertNil(service.place)
        XCTAssertNil(service.message)
        XCTAssertFalse(service.isLocating)
    }

    @MainActor func testCanceledLocationCannotPublishLateError() {
        let service = LocationService()
        service.cancel()
        service.receive(nil)
        XCTAssertNil(service.message)
    }
}
