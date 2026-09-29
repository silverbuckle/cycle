#if DEBUG
import CycleNaviCore

/// Synthetic, explicitly labeled UI fixture. Never used in release or normal launch.
struct PreviewRouteProvider: CyclingRouteProviding {
    func routes(for query: CyclingQuery) async throws -> RouteBatch {
        let route = try PlannedRoute(id: "ui-fixture", provider: .valhalla, name: "表示検証用の合成ルート（実走不可）",
            coordinates: [query.origin, Coordinate(latitude: 35.697, longitude: 139.573), query.destination],
            seconds: 600, meters: 1500,
            instructions: [RouteInstruction(text: "表示と音声の検証です。この線は走行用の経路ではありません。", meters: 500, shapeIndex: 0)],
            surface: .unknown)
        return RouteBatch(routes: [route], incomplete: false)
    }
    @MainActor static func makeModel() -> PlannerModel {
        let model = PlannerModel(provider: PreviewRouteProvider(), serviceDescription: "合成データによる画面検証 · 実走不可")
        model.select(Place(name: "検証用出発地", subtitle: "", coordinate: .init(latitude: 35.703, longitude: 139.58)), asOrigin: true)
        model.select(Place(name: "検証用目的地", subtitle: "", coordinate: .init(latitude: 35.69, longitude: 139.57)), asOrigin: false)
        return model
    }
}
#endif
