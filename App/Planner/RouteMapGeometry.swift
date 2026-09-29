import MapKit
import CycleNaviCore

extension PlannedRoute {
    var mapPolyline: MKPolyline {
        let points = coordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        return MKPolyline(coordinates: points, count: points.count)
    }
}
