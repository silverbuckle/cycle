import CoreLocation
import Observation

@Observable @MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var place: Place?
    private(set) var message: String?
    private(set) var isLocating = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func request() {
        place = nil
        message = nil
        switch manager.authorizationStatus {
        case .notDetermined:
            isLocating = true
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            isLocating = true
            manager.requestLocation()
        default:
            isLocating = false
            message = "位置情報を利用できません。設定で許可するか、出発地を検索してください。"
        }
    }

    func cancel() {
        isLocating = false
        manager.stopUpdatingLocation()
        place = nil
        message = nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self, self.isLocating else { return }
            self.request()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor [weak self] in self?.receive(locations.last) }
    }

    func receive(_ location: CLLocation?) {
        guard isLocating else { return }
        isLocating = false
        guard let location,
              CLLocationCoordinate2DIsValid(location.coordinate),
              location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 100,
              abs(location.timestamp.timeIntervalSinceNow) <= 30 else {
            message = "現在地を正確に取得できませんでした。もう一度試すか、出発地を検索してください。"
            return
        }
        place = Place(name: "現在地", subtitle: "取得時点の位置", coordinate: location.coordinate)
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            guard self?.isLocating == true else { return }
            self?.isLocating = false
            self?.message = "現在地を取得できませんでした。出発地を検索して計画できます。"
        }
    }
}
