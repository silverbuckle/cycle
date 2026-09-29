import MapKit

struct Place: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D

    @MainActor init(item: MKMapItem) {
        name = item.name ?? "選択した地点"
        subtitle = [item.placemark.administrativeArea, item.placemark.locality,
                    item.placemark.subLocality].compactMap { $0 }.joined(separator: " ")
        coordinate = item.placemark.coordinate
    }

    init(name: String, subtitle: String, coordinate: CLLocationCoordinate2D) {
        self.name = name
        self.subtitle = subtitle
        self.coordinate = coordinate
    }

    @MainActor var mapItem: MKMapItem {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        item.name = name
        return item
    }
}

struct RideRoute: Identifiable {
    let id = UUID()
    let route: MKRoute
}

enum PlannerError: LocalizedError {
    case noCyclingRoute
    var errorDescription: String? {
        "この区間の自転車経路を取得できませんでした。出発地・目的地を変えてお試しください。"
    }
}

@MainActor
struct AppleRouteService {
    func search(_ query: String) async throws -> [Place] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]
        // A search hint, not a geographical restriction.
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 35.67, longitude: 139.45),
            span: MKCoordinateSpan(latitudeDelta: 0.6, longitudeDelta: 0.6)
        )
        let result = try await MKLocalSearch(request: request).start()
        return result.mapItems.map { Place(item: $0) }
    }

    func routes(from: Place, to: Place) async throws -> [RideRoute] {
        let request = MKDirections.Request()
        request.source = from.mapItem
        request.destination = to.mapItem
        request.transportType = .cycling
        request.requestsAlternateRoutes = true
        let response = try await MKDirections(request: request).calculate()
        #if DEBUG
        NSLog("CycleNavi directions: requested=%lu returned=%@", request.transportType.rawValue,
              response.routes.map { "type=\($0.transportType.rawValue) seconds=\($0.expectedTravelTime) meters=\($0.distance) points=\($0.polyline.pointCount)" }.joined(separator: "; "))
        #endif
        let routes = response.routes.filter {
            $0.transportType.contains(.cycling) && $0.expectedTravelTime.isFinite &&
            $0.expectedTravelTime > 0 && $0.distance.isFinite && $0.distance > 0 &&
            $0.polyline.pointCount >= 2
        }
        guard !routes.isEmpty else { throw PlannerError.noCyclingRoute }
        return routes.map { RideRoute(route: $0) }
    }
}
