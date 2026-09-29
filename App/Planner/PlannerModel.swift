import MapKit
import Observation
import CycleNaviCore

@Observable @MainActor
final class PlannerModel {
    var origin: Place?
    var destination: Place?
    var bike: BikeKind = .gravel
    var extraMinutes = 15.0
    var pavedOnly = false
    private(set) var routes: [RideRoute] = []
    var selectedID: UUID?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var hasRequested = false
    private var requests = RequestGeneration()
    private var task: Task<Void, Never>?
    private let service = AppleRouteService()

    var eligibleRoutes: [RideRoute] {
        let candidates = routes.map {
            RouteCandidate(id: $0.id.uuidString, seconds: $0.route.expectedTravelTime,
                           accessAllowed: true, surface: .unknown)
        }
        guard let selection = try? selectRoutes(candidates,
            surface: pavedOnly ? .pavedOnly : .allowUnpaved,
            detour: .extraSeconds(extraMinutes * 60)) else { return [] }
        let ids = Set(selection.candidates.map(\.id))
        return routes.filter { ids.contains($0.id.uuidString) }
            .sorted { $0.route.expectedTravelTime < $1.route.expectedTravelTime }
    }

    var selected: RideRoute? { eligibleRoutes.first { $0.id == selectedID } }
    var fastestSeconds: Double? { routes.map { $0.route.expectedTravelTime }.min() }
    var canSearch: Bool { origin != nil && destination != nil && !isLoading }

    func select(_ place: Place, asOrigin: Bool) {
        resetRoutes()
        if asOrigin { origin = place } else { destination = place }
    }

    func swap() {
        let previous = origin
        origin = destination
        destination = previous
        resetRoutes()
    }

    func resetRoutes() {
        task?.cancel()
        requests.cancel()
        routes = []
        selectedID = nil
        isLoading = false
        errorMessage = nil
        hasRequested = false
    }

    func reconcileSelection() {
        if !eligibleRoutes.contains(where: { $0.id == selectedID }) {
            selectedID = eligibleRoutes.first?.id
        }
    }

    func searchRoutes() {
        guard let origin, let destination else { return }
        resetRoutes()
        let token = requests.begin()
        isLoading = true
        hasRequested = true
        task = Task {
            do {
                let result = try await service.routes(from: origin, to: destination)
                guard !Task.isCancelled, requests.accepts(token) else { return }
                routes = result
                isLoading = false
                reconcileSelection()
            } catch {
                guard !Task.isCancelled, requests.accepts(token) else { return }
                isLoading = false
                if let error = error as? PlannerError {
                    errorMessage = error.localizedDescription
                } else {
                    errorMessage = "経路を取得できませんでした。通信状態と、この地域の自転車経路対応をご確認ください。"
                }
            }
        }
    }
}
