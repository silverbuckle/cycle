import XCTest
import MapKit
import CycleNaviCore
@testable import CycleNavi

final class RouteMapGeometryTests: XCTestCase {
    func testGeometryIsNotResampledOrReordered() throws {
        let route = try PlannedRoute(id: "1", provider: .valhalla, name: "test",
            coordinates: [Coordinate(latitude: 35, longitude: 139), Coordinate(latitude: 35.1, longitude: 139.2)],
            seconds: 100, meters: 1000, instructions: [], surface: .unknown)
        let line = route.mapPolyline
        var result = [CLLocationCoordinate2D](repeating: .init(), count: line.pointCount)
        line.getCoordinates(&result, range: NSRange(location: 0, length: line.pointCount))
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].latitude, 35, accuracy: 0.000001)
        XCTAssertEqual(result[1].longitude, 139.2, accuracy: 0.000001)
    }
    @MainActor func testAppleUnverifiedTransportRejected() {
        XCTAssertThrowsError(try AppleRouteService.normalize(MKRoute()))
    }
}
