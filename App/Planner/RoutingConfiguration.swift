import Foundation
import CycleNaviCore

struct RoutingConfiguration {
    let endpoint: RoutingEndpoint?
    init(rawEndpoint: String) throws {
        endpoint = rawEndpoint.isEmpty ? nil : try RoutingEndpoint(rawEndpoint)
    }
    @MainActor func makeModel() -> PlannerModel {
        guard let endpoint else {
            return PlannerModel(provider: UnconfiguredRoutes(), isConfigured: false,
                                serviceDescription: "経路サービス未設定")
        }
        let client = ValhallaClient(endpoint: endpoint, transport: URLSessionRouteTransport())
        return PlannerModel(provider: CyclingRoutePlanner { query, intent in
            try await client.route(query, intent: intent)
        }, serviceDescription: "Valhalla · 送信先 \(endpoint.routeURL.host ?? "")")
    }
    @MainActor static func applicationModel() -> PlannerModel {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-route-fixture") {
            return PreviewRouteProvider.makeModel()
        }
        #endif
        let raw = ProcessInfo.processInfo.environment["CYCLENAVI_VALHALLA_ROUTE_URL"]
            ?? Bundle.main.object(forInfoDictionaryKey: "CYCLENAVI_VALHALLA_ROUTE_URL") as? String ?? ""
        do { return try RoutingConfiguration(rawEndpoint: raw).makeModel() }
        catch {
            return PlannerModel(provider: UnconfiguredRoutes(), isConfigured: false,
                                serviceDescription: "経路サービスの接続先設定が不正です")
        }
    }
}

private struct UnconfiguredRoutes: CyclingRouteProviding {
    func routes(for query: CyclingQuery) async throws -> RouteBatch { throw RoutingFailure.unconfigured }
}
