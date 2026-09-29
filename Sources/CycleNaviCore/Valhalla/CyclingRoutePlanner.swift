public struct RouteBatch: Sendable {
    public let routes: [PlannedRoute]
    public let incomplete: Bool
    public init(routes: [PlannedRoute], incomplete: Bool) {
        self.routes = routes; self.incomplete = incomplete
    }
}

public protocol CyclingRouteProviding: Sendable {
    func routes(for query: CyclingQuery) async throws -> RouteBatch
}

public struct CyclingRoutePlanner: CyclingRouteProviding {
    private let fetch: @Sendable (CyclingQuery, CandidateIntent) async throws -> PlannedRoute
    public init(fetch: @escaping @Sendable (CyclingQuery, CandidateIntent) async throws -> PlannedRoute) {
        self.fetch = fetch
    }
    public func routes(for query: CyclingQuery) async throws -> RouteBatch {
        var routes: [PlannedRoute] = []
        var firstFailure: (any Error)?
        for intent in [CandidateIntent.baseline, .preferred] {
            try Task.checkCancellation()
            do {
                let route = try await fetch(query, intent)
                try Task.checkCancellation()
                if !routes.contains(where: { $0.coordinates == route.coordinates }) { routes.append(route) }
            } catch is CancellationError { throw CancellationError() }
            catch { if firstFailure == nil { firstFailure = error } }
        }
        try Task.checkCancellation()
        guard !routes.isEmpty else { throw firstFailure ?? RoutingFailure.noRoute }
        return RouteBatch(routes: routes, incomplete: firstFailure != nil)
    }
}
