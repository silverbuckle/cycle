import MapKit
import Observation
import CycleNaviCore

@Observable @MainActor
final class PlannerModel {
    var origin: Place?
    var destination: Place?
    var bike: BikeKind = .gravel { didSet { if bike != oldValue { resetRoutes() } } }
    var useRoads = 0.25 { didSet { if useRoads != oldValue { resetRoutes() } } }
    var useHills = 0.25 { didSet { if useHills != oldValue { resetRoutes() } } }
    var avoidBadSurfaces = 0.75 { didSet { if avoidBadSurfaces != oldValue { resetRoutes() } } }
    var extraMinutes = 15.0 { didSet { reconcileSelection() } }
    var pavedOnly = false { didSet { reconcileSelection() } }
    private(set) var routes: [PlannedRoute] = []
    var selectedID: String?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var warningMessage: String?
    private(set) var hasRequested = false
    let isConfigured: Bool
    let serviceDescription: String
    private var requests = RequestGeneration()
    private var task: Task<Void, Never>?
    private let provider: any CyclingRouteProviding

    init(provider: any CyclingRouteProviding, isConfigured: Bool = true, serviceDescription: String = "Valhalla") {
        self.provider = provider
        self.isConfigured = isConfigured
        self.serviceDescription = serviceDescription
    }

    var eligibleRoutes: [PlannedRoute] {
        let candidates = routes.map {
            RouteCandidate(id: $0.id, seconds: $0.seconds, accessAllowed: true, surface: $0.surface)
        }
        guard let selection = try? selectRoutes(candidates,
            surface: pavedOnly ? .pavedOnly : .allowUnpaved,
            detour: .extraSeconds(extraMinutes * 60)) else { return [] }
        let ids = Set(selection.candidates.map(\.id))
        return routes.filter { ids.contains($0.id) }.sorted { $0.seconds < $1.seconds }
    }

    var selected: PlannedRoute? { eligibleRoutes.first { $0.id == selectedID } }
    var fastestSeconds: Double? { eligibleRoutes.map(\.seconds).min() }
    var canSearch: Bool { isConfigured && origin != nil && destination != nil && !isLoading }

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
        warningMessage = nil
        hasRequested = false
    }

    func reconcileSelection() {
        if !eligibleRoutes.contains(where: { $0.id == selectedID }) {
            selectedID = eligibleRoutes.first?.id
        }
    }

    @discardableResult func searchRoutes() -> Task<Void, Never>? {
        guard canSearch, let origin, let destination else { return nil }
        resetRoutes()
        let query: CyclingQuery
        do {
            query = try CyclingQuery(
                origin: Coordinate(latitude: origin.coordinate.latitude, longitude: origin.coordinate.longitude),
                destination: Coordinate(latitude: destination.coordinate.latitude, longitude: destination.coordinate.longitude),
                bike: bike, preferences: CyclingPreferences(useRoads: useRoads, useHills: useHills,
                                                           avoidBadSurfaces: avoidBadSurfaces))
        } catch {
            errorMessage = "地点または設定が正しくありません。選び直してください。"
            return nil
        }
        let token = requests.begin()
        isLoading = true
        hasRequested = true
        task = Task {
            do {
                let batch = try await provider.routes(for: query)
                guard !Task.isCancelled, requests.accepts(token) else { return }
                routes = batch.routes
                warningMessage = batch.incomplete ? "一部の候補を取得できませんでした。比較結果は不完全です。" : nil
                isLoading = false
                reconcileSelection()
            } catch {
                guard requests.accepts(token) else { return }
                isLoading = false
                if error is CancellationError { hasRequested = false; return }
                errorMessage = Self.message(for: error)
            }
        }
        return task
    }

    private static func message(for error: Error) -> String {
        switch error as? RoutingFailure {
        case .unconfigured: "経路サービス未設定です。"
        case .invalidEndpoint: "経路サービスの接続先設定を確認してください。"
        case .noRoute: "この条件で自転車経路を取得できませんでした。"
        case .rateLimited: "経路サービスが混み合っています。時間をおいて試してください。"
        case .timeout: "経路取得がタイムアウトしました。通信状態をご確認ください。"
        case .invalidResponse: "経路データを確認できなかったため表示しませんでした。"
        default: "経路を取得できませんでした。通信状態と接続先をご確認ください。"
        }
    }
}
